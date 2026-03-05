const std = @import("std");
const zcc = @import("compile_commands");
const zbk = @import("zbk");

const LIBS_WINDOWS = [_][]const u8{
    "gdi32",
    "kernel32",
    "opengl32",
};

const LIBS_WAYLAND = [_][]const u8{
    "wayland-client",
    "wayland-egl",
};

pub fn build(b: *std.Build) !void {
    var targets = std.ArrayListUnmanaged(*std.Build.Step.Compile){};

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    std.log.info("{s}({s})", .{ try target.result.linuxTriple(b.allocator), @tagName(optimize) });

    const exe = b.addExecutable(.{
        .name = "hello_xr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .use_llvm = true,
    });
    targets.append(b.allocator, exe) catch @panic("OOM");
    b.installArtifact(exe);

    const openxr_dep = b.dependency("openxr", .{});
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

    const t = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path(if (target.result.os.tag == .windows)
            "c_windows.h"
        else
            "c_wayland.h"),
    });
    t.addIncludePath(openxr_dep.path("include"));
    t.addIncludePath(b.path("glad2/include"));

    const c_mod = t.createModule();
    exe.root_module.addImport("c", c_mod);

    exe.addLibraryPath(openxr_loader.getInstallPrefix().path(b, "lib"));
    exe.linkSystemLibrary("openxr_loader");

    const glad = try build_glad(b, target, optimize, b.path("glad2"));
    exe.linkLibrary(glad);

    if (target.result.os.tag == .windows) {
        for (LIBS_WINDOWS) |lib| {
            exe.linkSystemLibrary(lib);
        }
    } else {
        for (LIBS_WAYLAND) |lib| {
            exe.linkSystemLibrary(lib);
        }
    }

    const zcc_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    exe.step.dependOn(zcc_step);
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
