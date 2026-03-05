const std = @import("std");
const zcc = @import("compile_commands");
const zbk = @import("zbk");

const BUILD_NAME = "hello_xr";
const PKG_NAME = "com.zig." ++ BUILD_NAME;
const API_LEVEL = 35;

const LIBS_WINDOWS = [_][]const u8{
    "gdi32",
    "kernel32",
    "opengl32",
};

const LIBS_WAYLAND = [_][]const u8{
    "wayland-client",
    "wayland-egl",
};

const LIBS_ANDROID = [_][]const u8{
    "android",
    "log",
    "EGL",
    "GLESv1_CM",
    "GLESv2",
    "GLESv3",
};

pub fn build(b: *std.Build) !void {
    var targets = std.ArrayListUnmanaged(*std.Build.Step.Compile){};

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    std.log.info("{s}({s})", .{ try target.result.linuxTriple(b.allocator), @tagName(optimize) });

    const openxr_dep = b.dependency("openxr", .{});

    const bin = if (target.result.abi.isAndroid()) blk: {
        const lib = b.addLibrary(.{
            .name = BUILD_NAME,
            .root_module = b.createModule(.{
                .root_source_file = b.path("main_android.zig"),
                .target = target,
                .optimize = optimize,
                .link_libcpp = true,
            }),
            .linkage = .dynamic,
            .use_llvm = true,
        });
        lib.addCSourceFiles(.{
            .files = &.{
                "android_helper.cpp",
            },
        });

        // const ndk_path = try zbk.android.ndk.getPath(b, .{ .android_home = android_home });
        const sdk_info = try zbk.android.SdkInfo.init(b.allocator, if (target.result.os.tag == .windows) .androidstudio else .opt);

        const libc_file = try zbk.android.ndk.LibCFile.make(b, sdk_info.ndk_path, target, API_LEVEL);
        // for compile
        lib.addSystemIncludePath(.{ .cwd_relative = libc_file.include_dir });
        lib.addSystemIncludePath(.{ .cwd_relative = libc_file.sys_include_dir });
        // for link
        lib.setLibCFile(libc_file.path);
        lib.addLibraryPath(.{ .cwd_relative = libc_file.crt_dir });

        // native_app_glue (android_main dependency)
        lib.addCSourceFile(.{ .file = .{ .cwd_relative = b.fmt(
            "{s}/sources/android/native_app_glue/android_native_app_glue.c",
            .{sdk_info.ndk_path},
        ) } });
        lib.addIncludePath(.{ .cwd_relative = b.fmt("{s}/sources/android/native_app_glue", .{sdk_info.ndk_path}) });

        const c_mod = build_c_mod_android(b, target, optimize, openxr_dep.path("include"), &.{
            .{ .cwd_relative = libc_file.include_dir },
            .{ .cwd_relative = libc_file.sys_include_dir },
            .{ .cwd_relative = b.fmt("{s}/sources/android/native_app_glue", .{sdk_info.ndk_path}) },
        });
        lib.root_module.addImport("c", c_mod);

        const openxr_loader = zbk.cpp.CMakeStep.create(b, .{
            .source = openxr_dep.path("").getPath(b),
            .use_vcenv = target.result.os.tag == .windows,
            .ndk_path = sdk_info.ndk_path,
            .args = if (target.result.os.tag == .windows) &.{"-DDYNAMIC_LOADER=ON"} else &.{},
        });
        lib.addLibraryPath(openxr_loader.getInstallPrefix().path(b, "lib"));
        lib.linkSystemLibrary("openxr_loader");

        // android sdk
        const apk_builder = try zbk.android.ApkBuilder.init(b, .{
            .sdk_info = sdk_info,
            .api_level = API_LEVEL,
        });

        const keystore_password = "example_password";
        const keystore = apk_builder.jdk.makeKeystore(b, keystore_password);

        // make apk from
        const apk = apk_builder.makeApk(b, .{
            .android_manifest = try zbk.android.generateAndroidManifest(b, .{
                .pkg_name = PKG_NAME,
                .api_level = API_LEVEL,
                .android_label = lib.name,
            }),
            .resource_dir = b.path("res"),
            .keystore_password = keystore_password,
            .keystore_file = keystore.output,
            .copy_list = &.{
                .{ .src = lib.getEmittedBin() },
            },
        });
        const install = b.addInstallFile(apk, "bin/hello_xr.apk");
        b.getInstallStep().dependOn(&install.step);

        // adb install
        // adb run
        const run_step = b.step("run", "Install and run the application on an Android device");
        const adb_install = apk_builder.platform_tools.adb_install(b, install.source);
        const adb_start = apk_builder.platform_tools.adb_start(b, .{ .package_name = PKG_NAME });
        adb_start.step.dependOn(&adb_install.step);
        run_step.dependOn(&adb_start.step);

        break :blk lib;
    } else blk: {
        const exe = b.addExecutable(.{
            .name = BUILD_NAME,
            .root_module = b.createModule(.{
                .root_source_file = b.path("main.zig"),
                .target = target,
                .optimize = optimize,
                .link_libcpp = true,
            }),
            .use_llvm = true,
        });

        const c_mod = build_c_mod(
            b,
            target,
            optimize,
            b.path(if (target.result.os.tag == .windows) "c_windows.h" else "c_wayland.h"),
            &.{ openxr_dep.path("include"), b.path("glad2/include") },
        );
        exe.root_module.addImport("c", c_mod);

        const openxr_loader = zbk.cpp.CMakeStep.create(b, .{
            .source = openxr_dep.path("").getPath(b),
            .use_vcenv = target.result.os.tag == .windows,
            .args = if (target.result.os.tag == .windows) &.{"-DDYNAMIC_LOADER=ON"} else &.{},
        });
        if (target.result.os.tag == .windows) {
            // copy dll
            const dll = b.addInstallBinFile(
                openxr_loader.getInstallPrefix().path(b, "bin/openxr_loader.dll"),
                "openxr_loader.dll",
            );
            b.getInstallStep().dependOn(&dll.step);
        }
        exe.addLibraryPath(openxr_loader.getInstallPrefix().path(b, "lib"));
        exe.linkSystemLibrary("openxr_loader");

        break :blk exe;
    };
    targets.append(b.allocator, bin) catch @panic("OOM");
    b.installArtifact(bin);

    if (!target.result.abi.isAndroid()) {
        const glad = try build_glad(b, target, optimize, b.path("glad2"));
        bin.linkLibrary(glad);
    }

    if (target.result.abi.isAndroid()) {
        for (LIBS_ANDROID) |lib| {
            bin.linkSystemLibrary(lib);
        }
    } else if (target.result.os.tag == .windows) {
        for (LIBS_WINDOWS) |lib| {
            bin.linkSystemLibrary(lib);
        }
    } else {
        for (LIBS_WAYLAND) |lib| {
            bin.linkSystemLibrary(lib);
        }
    }

    const zcc_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    bin.step.dependOn(zcc_step);
}

fn build_c_mod_android(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    openxr_header: std.Build.LazyPath,
    system_includes: []const std.Build.LazyPath,
) *std.Build.Module {
    const t = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("c_android.h"),
    });
    t.addIncludePath(openxr_header);
    for (system_includes) |include| {
        t.addSystemIncludePath(include);
    }
    return t.createModule();
}

fn build_c_mod(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    c_header: std.Build.LazyPath,
    includes: []const std.Build.LazyPath,
) *std.Build.Module {
    const t = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = c_header,
    });
    for (includes) |include| {
        t.addIncludePath(include);
    }

    return t.createModule();
}

pub fn build_glad(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
) !*std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "glad2",
        // .root_module = t.createModule(),
        .root_module = b.addModule("glad2", .{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        // .use_llvm = true,
    });
    const srcs = [_][]const u8{
        "gl.c",
    };
    const srcs_windows = [_][]const u8{
        "wgl.c",
    };
    const srcs_linux = [_][]const u8{
        "egl.c",
        "glx.c",
    };
    lib.addCSourceFiles(.{
        .root = src.path(b, "src"),
        .files = &(if (target.result.os.tag == .windows)
            srcs ++ srcs_windows
        else
            srcs ++ srcs_linux),
    });
    lib.addIncludePath(src.path(b, "include"));
    lib.installHeadersDirectory(src.path(b, "include/glad"), "glad", .{});

    return lib;
}
