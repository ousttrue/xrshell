const std = @import("std");
const zcc = @import("compile_commands");
const zbk = @import("zbk");

const BUILD_NAME = "hello_xr";
const PKG_NAME = "com.zig." ++ BUILD_NAME;
const API_LEVEL = 35;

const LIBS_WINDOWS = [_][]const u8{
    "user32",
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
                "android/android_helper.cpp",
            },
        });

        // const ndk_path = try zbk.android.ndk.getPath(b, .{ .android_home = android_home });
        const sdk_info = try zbk.android.SdkInfo.init(b.allocator, if (b.graph.host.result.os.tag == .windows)
            .androidstudio
        else
            .opt);

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

        const c_mod = build_c_mod_android(b, target, optimize, &.{
            openxr_dep.path("include"),
            // b.path("glad2/include"),
        }, &.{
            .{ .cwd_relative = libc_file.include_dir },
            .{ .cwd_relative = libc_file.sys_include_dir },
            .{ .cwd_relative = b.fmt("{s}/sources/android/native_app_glue", .{sdk_info.ndk_path}) },
        });
        lib.root_module.addImport("c", c_mod);

        const openxr_loader = zbk.cpp.CMakeStep.create(b, .{
            .source = openxr_dep.path("").getPath(b),
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
            .android_manifest = b.path("android/AndroidManifest.xml"),
            .keystore_password = keystore_password,
            .keystore_file = keystore.output,
            .resource_dir = b.path("android/res"),
            .copy_list = &.{
                .{
                    .src = lib.getEmittedBin(),
                    .dst = "lib/arm64-v8a/libmain.so",
                },
                .{
                    .src = openxr_loader.getInstallPrefix().path(b, "lib/libopenxr_loader.so"),
                    .dst = "lib/arm64-v8a/libopenxr_loader.so",
                },
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

        // const openxr_loader = zbk.cpp.CMakeStep.create(b, .{
        //     .source = openxr_dep.path("").getPath(b),
        //     .target = target,
        //     .use_vcenv = b.graph.host.result.os.tag == .windows,
        //     .args = if (target.result.os.tag == .windows) &.{"-DDYNAMIC_LOADER=ON"} else &.{},
        // });
        // if (target.result.os.tag == .windows) {
        //     // copy dll
        //     const dll = b.addInstallBinFile(
        //         openxr_loader.getInstallPrefix().path(b, "bin/openxr_loader.dll"),
        //         "openxr_loader.dll",
        //     );
        //     b.getInstallStep().dependOn(&dll.step);
        // }
        // exe.addLibraryPath(openxr_loader.getInstallPrefix().path(b, "lib"));
        // exe.linkSystemLibrary("openxr_loader");
        const openxr_flags: []const []const u8 = if (target.result.os.tag == .windows)
            &.{
                "-DXR_OS_WINDOWS",
                "-DNOMINMAX",
                "-DXR_USE_PLATFORM_WIN32",
            }
        else if (target.result.abi.isAndroid())
            &.{"-DXR_OS_ANDROID"}
        else
            &.{"-DXR_OS_LINUX"};
        exe.addCSourceFiles(.{
            .root = openxr_dep.path("src"),
            .files = &.{
                "loader/android_utilities.cpp",
                "loader/api_layer_interface.cpp",
                "loader/loader_core.cpp",
                "loader/loader_init_data.cpp",
                "loader/loader_instance.cpp",
                "loader/loader_logger.cpp",
                "loader/loader_logger_recorders.cpp",
                "loader/loader_properties.cpp",
                "loader/manifest_file.cpp",
                "loader/runtime_interface.cpp",
                "common/object_info.cpp",
                "common/filesystem_utils.cpp",
                //
                "xr_generated_dispatch_table.c",
                "xr_generated_dispatch_table_core.c",
                "loader/xr_generated_loader.cpp",
                //
                "external/jsoncpp/src/lib_json/json_reader.cpp",
                "external/jsoncpp/src/lib_json/json_writer.cpp",
                "external/jsoncpp/src/lib_json/json_value.cpp",
            },
            .flags = openxr_flags,
        });
        exe.addIncludePath(openxr_dep.path("src/external/jsoncpp/include"));
        exe.addIncludePath(openxr_dep.path("src/common"));
        exe.addIncludePath(openxr_dep.path("src"));
        exe.addIncludePath(openxr_dep.path("include"));

        const srcs = [_][]const u8{
            "gl.c",
        };
        const srcs_windows = [_][]const u8{
            "wgl.c",
        };
        const srcs_wayland = [_][]const u8{
            "egl.c",
            // "glx.c",
        };
        exe.addCSourceFiles(.{
            .root = b.path("glad2/src"),
            .files = &(if (target.result.os.tag == .windows)
                srcs ++ srcs_windows
            else
                srcs ++ srcs_wayland),
            .flags = &.{
                // "-DGLAD_GLES2",
            },
        });
        exe.addIncludePath(b.path("glad2/include"));

        break :blk exe;
    };
    targets.append(b.allocator, bin) catch @panic("OOM");
    b.installArtifact(bin);

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
    includes: []const std.Build.LazyPath,
    system_includes: []const std.Build.LazyPath,
) *std.Build.Module {
    const t = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("android/c_android.h"),
    });
    for (includes) |include| {
        t.addIncludePath(include);
    }
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

// pub fn add_glad(
//     b: *std.Build,
//     target: std.Build.ResolvedTarget,
//     // optimize: std.builtin.OptimizeMode,
//     lib: *std.Build.Step.Compile,
//     src: std.Build.LazyPath,
// ) void {
//     // const lib = b.addLibrary(.{
//     //     .name = "glad2",
//     //     // .root_module = t.createModule(),
//     //     .root_module = b.addModule("glad2", .{
//     //         .target = target,
//     //         .optimize = optimize,
//     //         .link_libc = true,
//     //     }),
//     //     // .use_llvm = true,
//     // });
//     lib.addIncludePath(src.path(b, "include"));
//     lib.installHeadersDirectory(src.path(b, "include/glad"), "glad", .{});
//
//     // return lib;
// }
