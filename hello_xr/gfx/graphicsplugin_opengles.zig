const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("../xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const Cube = @import("../Cube.zig");
const xr_linear = @import("xr_linear.zig");

const private = struct {
    var m_contextApiMajorVersion: c.GLint = 0;

    fn requirements(instance: c.XrInstance, systemId: c.XrSystemId) !void {
        // Extension function must be loaded by name
        var pfn: c.PFN_xrGetOpenGLESGraphicsRequirementsKHR = undefined;
        _ = try XrResult.init(c.xrGetInstanceProcAddr(instance, "xrGetOpenGLESGraphicsRequirementsKHR", &pfn));

        var graphicsRequirements: c.XrGraphicsRequirementsOpenGLESKHR = .{ .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_OPENGL_ES_KHR };
        _ = try XrResult.init(pfn.?(instance, systemId, &graphicsRequirements));

        // gfxwrapper_opengl.init();

        var major: c.GLint = 0;
        c.glGetIntegerv(c.GL_MAJOR_VERSION, &major);
        var minor: c.GLint = 0;
        c.glGetIntegerv(c.GL_MINOR_VERSION, &minor);

        const desiredApiVersion: c.XrVersion = c.XR_MAKE_VERSION(@as(u64, @intCast(major)), @as(u64, @intCast(minor)), 0);
        if (graphicsRequirements.minApiVersionSupported > desiredApiVersion) {
            @panic("Runtime does not support desired Graphics API and/or version");
        }

        m_contextApiMajorVersion = major;
    }

    fn selectColorSwapchainFormat(allocator: std.mem.Allocator, runtimeFormats: []const i64) !i64 {
        // List of supported color swapchain formats.
        var supportedColorSwapchainFormats: std.ArrayList(i64) = .{};
        defer supportedColorSwapchainFormats.deinit(allocator);
        try supportedColorSwapchainFormats.append(allocator, c.GL_RGBA8);
        try supportedColorSwapchainFormats.append(allocator, c.GL_RGBA8_SNORM);

        // In OpenGLES 3.0+, the R, G, and B values after blending are converted into the non-linear
        // sRGB automatically.
        if (m_contextApiMajorVersion >= 3) {
            try supportedColorSwapchainFormats.append(allocator, c.GL_SRGB8_ALPHA8);
        }

        for (runtimeFormats) |f| {
            for (supportedColorSwapchainFormats.items) |s| {
                if (f == s) {
                    return f;
                }
            }
        }

        @panic("No runtime swapchain format supported for color swapchain");
    }

    fn getSupportedSwapchainSampleCount() u32 {
        return 1;
    }
};

pub const binding = if (builtin.abi.isAndroid())
    struct {
        pub const GraphicsBinding = c.XrGraphicsBindingOpenGLESAndroidKHR;
        pub const extensions = [_][*:0]const u8{c.XR_KHR_OPENGL_ES_ENABLE_EXTENSION_NAME};
        pub fn makeBinding(window: anytype) GraphicsBinding {
            return .{
                .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_ES_ANDROID_KHR,
                .next = null,
                .display = window.dpy,
                .config = null,
                .context = window.ctx,
            };
        }
        pub const swapchain_image: c.XrSwapchainImageOpenGLESKHR = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_ES_KHR };
        pub const requirements = private.requirements;
        pub const selectColorSwapchainFormat = private.selectColorSwapchainFormat;
        pub const getSupportedSwapchainSampleCount = private.getSupportedSwapchainSampleCount;
    }
else
    struct {
        pub const GraphicsBinding = c.XrGraphicsBindingEGLMNDX;
        pub const extensions = [_][*:0]const u8{c.XR_MNDX_EGL_ENABLE_EXTENSION_NAME};
        export fn eglGetProcAddress(name: [*c]const u8) c.PFN_xrEglGetProcAddressMNDX {
            return @ptrCast(c.eglGetProcAddress(name));
        }
        pub fn makeBinding(window: anytype) GraphicsBinding {
            return .{
                .type = c.XR_TYPE_GRAPHICS_BINDING_EGL_MNDX,
                .next = null,
                .getProcAddress = @ptrCast(&eglGetProcAddress),
                .display = window.display,
                .config = window.config,
                .context = window.context,
            };
        }
        pub const swapchain_image: c.XrSwapchainImageOpenGLESKHR = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_ES_KHR };
    };
