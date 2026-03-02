const std = @import("std");
const zbk = @import("zbk");
const zcc = @import("compile_commands");

const GFX_FLAGS = [_][]const u8{
    // "-DOS_LINUX_XCB",
    "-DOS_LINUX_XCB_GLX",
    // "-DOS_LINUX_WAYLAND",
    "-DXR_USE_GRAPHICS_API_OPENGL",
};

const XR_FLAGS = [_][]const u8{
    "-DXR_OS_LINUX",
    "-DXR_USE_PLATFORM_XCB",
    // "-DXR_USE_PLATFORM_WAYLAND",
    // "-DXR_USE_GRAPHICS_API_OPENGL_ES",
    "-DXR_USE_GRAPHICS_API_OPENGL",
};

const XR_SRCS = [_][]const u8{
    // "platformplugin_android.cpp",
    "platform/platformplugin_posix.cpp",
    // "platformplugin_win32.cpp",
    // "platform/platformplugin_factory.cpp",

    // "d3d_common.cpp",
    // "graphicsplugin_d3d11.cpp",
    // "graphicsplugin_d3d12.cpp",
    "graphicsplugin_opengl.cpp",
    // "graphicsplugin_opengles.cpp",
    // "graphicsplugin_vulkan.cpp",
    // "graphicsplugin_metal.cpp",
    "graphicsplugin_factory.cpp",

    "logger.cpp",
    "main.cpp",
    "openxr_program.cpp",
};

const LIBS = [_][]const u8{
    // "wayland-cursor",
    // "wayland-egl",
    "EGL",
    "GLESv2",
    // "wayland-client",
    "X11-xcb",
    "xcb",
    "xcb-randr",
    "xcb-xkb",
    "xcb-keysyms",
};

pub fn build(b: *std.Build) void {
    var targets = std.ArrayListUnmanaged(*std.Build.Step.Compile){};

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const mod = b.addModule("hello_xr", .{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    // });

    const exe = b.addExecutable(.{
        .name = "hello_xr",
        .root_module = b.createModule(.{
            // .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // .imports = &.{
            //     .{ .name = "hello_xr", .module = mod },
            // },
            .link_libcpp = true,
        }),
        // .use_llvm = true,
    });
    targets.append(b.allocator, exe) catch @panic("OOM");
    exe.addCSourceFiles(.{
        .files = &XR_SRCS,
        .flags = &(XR_FLAGS ++ GFX_FLAGS),
    });
    exe.addIncludePath(b.path(""));

    const openxr_dep = b.dependency("openxr", .{});
    exe.addIncludePath(openxr_dep.path("include"));
    // const zbk_dep = b.dependency("zbk", .{
    //     .openxr = openxr_dep.path(""),
    // });
    const openxr_loader = zbk.cpp.CMakeStep.create(b, .{
        .source = openxr_dep.path("").getPath(b),
        .use_vcenv = target.result.os.tag == .windows,
        // .args = &.{"-DDYNAMIC_LOADER=ON"},
    });
    exe.addLibraryPath(openxr_loader.getInstallPrefix().path(b, "lib"));
    exe.linkSystemLibrary("openxr_loader");

    const options = b.addLibrary(.{
        .name = "Options",
        .root_module = b.addModule("Options", .{
            .root_source_file = b.path("Options.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    options.addIncludePath(openxr_dep.path("include"));
    exe.linkLibrary(options);

    const glad = try build_glad(b, target, optimize, b.path("glad2"));
    exe.linkLibrary(glad);

    const gfx = build_gfxwrapper_opengl(b, target, optimize, b.path("gfxwrapper_opengl"));
    gfx.linkLibrary(glad);
    exe.linkLibrary(gfx);

    for (LIBS) |lib| {
        exe.linkSystemLibrary(lib);
    }

    b.installArtifact(exe);

    // exe.addIncludePath(wayland_scanner(
    //     b,
    //     &.{ "client-header", "/usr/share/wayland-protocols/unstable/xdg-shell/xdg-shell-unstable-v6.xml" },
    //     "xdg-shell-unstable-v6.h",
    // ).dirname());
    // exe.addCSourceFile(.{
    //     .file = wayland_scanner(
    //         b,
    //         &.{ "public-code", "/usr/share/wayland-protocols/unstable/xdg-shell/xdg-shell-unstable-v6.xml" },
    //         "xdg-shell-unstable-v6.c",
    //     ),
    // });

    //
    //
    //
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    exe.step.dependOn(zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM")));
}

fn build_gfxwrapper_opengl(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const name = "gfxwrapper_opengl";
    const lib = b.addLibrary(.{
        .name = name,
        .root_module = b.addModule(name, .{
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.addCSourceFiles(.{
        .root = root,
        .files = &.{
            "gfxwrapper_opengl.c",
        },
        .flags = &GFX_FLAGS,
    });
    lib.installHeader(root.path(b, "gfxwrapper_opengl.h"), "gfxwrapper_opengl.h");
    return lib;
}

fn wayland_scanner(
    b: *std.Build,
    args: []const []const u8,
    output: []const u8,
) std.Build.LazyPath {
    const run = b.addSystemCommand(&.{"wayland-scanner"});
    run.addArgs(args);
    return run.addOutputFileArg(output);
}

pub fn build_glad(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: std.Build.LazyPath,
) !*std.Build.Step.Compile {
    // const t = b.addTranslateC(.{
    //     .root_source_file = src.path(b, "include/glad/gl.h"),
    //     .target = target,
    //     .optimize = optimize,
    // });
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
    lib.addCSourceFiles(.{
        .root = src.path(b, "src"),
        .files = &.{
            "gl.c",
            "glx.c",
            "egl.c",
        },
    });
    lib.addIncludePath(src.path(b, "include"));
    lib.installHeadersDirectory(src.path(b, "include/glad"), "glad", .{});

    return lib;
}
