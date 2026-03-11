const std = @import("std");
const c = @import("c");

pub fn SelectColorSwapchainFormat(_: std.mem.Allocator, runtimeFormats: []i64) !i64 {
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

pub const swapchain_image: c.XrSwapchainImageOpenGLKHR = .{
    .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_KHR,
};

pub fn GetSupportedSwapchainSampleCount() u32 {
    return 1;
}
