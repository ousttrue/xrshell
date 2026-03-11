const std = @import("std");
const c = @import("c");
const xrs = @import("../xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;

pub const Binding = c.XrGraphicsBindingOpenGLWin32KHR;

pub const extensions = [_][*:0]const u8{
    c.XR_KHR_OPENGL_ENABLE_EXTENSION_NAME,
};

pub const swapchain_image: c.XrSwapchainImageOpenGLKHR = .{
    .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_KHR,
};

pub fn makeBinding(window: anytype) Binding {
    return .{
        .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR,
        .next = null,
        .hDC = window.hDC,
        .hGLRC = window.hGLRC,
    };
}

pub fn requirements(instance: c.XrInstance, systemId: c.XrSystemId) !void {
    // pub fn InitializeDevice(instance: c.XrInstance, systemId: c.XrSystemId) XrError!void {
    // Extension function must be loaded by name
    var pfnGetOpenGLGraphicsRequirementsKHR: c.PFN_xrGetOpenGLGraphicsRequirementsKHR = undefined;
    _ = try XrResult.init(c.xrGetInstanceProcAddr(instance, "xrGetOpenGLGraphicsRequirementsKHR", &pfnGetOpenGLGraphicsRequirementsKHR));

    var graphicsRequirements: c.XrGraphicsRequirementsOpenGLKHR = .{ .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_OPENGL_KHR };
    _ = try XrResult.init((pfnGetOpenGLGraphicsRequirementsKHR.?)(instance, systemId, &graphicsRequirements));

    var major: c.GLint = 0;
    c.glGetIntegerv(c.GL_MAJOR_VERSION, &major);
    var minor: c.GLint = 0;
    c.glGetIntegerv(c.GL_MINOR_VERSION, &minor);

    const desiredApiVersion = c.XR_MAKE_VERSION(@as(i64, @intCast(major)), @as(i64, @intCast(minor)), 0);
    if (graphicsRequirements.minApiVersionSupported > desiredApiVersion) {
        @panic("Runtime does not support desired Graphics API and/or version");
    }
}

pub fn selectColorSwapchainFormat(_: std.mem.Allocator, runtimeFormats: []i64) !i64 {
    // List of supported color swapchain formats.
    const SupportedColorSwapchainFormats = [_]i64{
        c.GL_RGB10_A2,
        c.GL_RGBA16F,
        // The two below should only be used as a fallback,
        // as they are linear color formats without enough bits for color
        // depth, thus leading to banding.
        c.GL_RGBA8,
        c.GL_RGBA8_SNORM,
    };

    for (runtimeFormats) |f| {
        for (SupportedColorSwapchainFormats) |s| {
            if (f == s) {
                return f;
            }
        }
    }

    @panic("No runtime swapchain format supported for color swapchain");
}

pub fn getSupportedSwapchainSampleCount() u32 {
    return 1;
}
