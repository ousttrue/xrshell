const std = @import("std");
const c = @import("c");

var m_swapchainImageBuffers: std.ArrayList([]c.XrSwapchainImageOpenGLKHR) = .{};

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

pub fn AllocateSwapchainImageStructs(
    allocator: std.mem.Allocator,
    swapchainImageBase: []*c.XrSwapchainImageBaseHeader,
) !void {
    // Allocate and initialize the buffer of image structs
    // (must be sequential in memory for xrEnumerateSwapchainImages).
    // Return back an array of pointers to each swapchain image struct
    // so the consumer doesn't need to know the type/size.
    const swapchainImageBuffer = try allocator.alloc(c.XrSwapchainImageOpenGLKHR, swapchainImageBase.len);
    for (swapchainImageBuffer) |*buf| {
        buf.* = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_KHR };
    }

    for (swapchainImageBuffer, 0..) |*buf, i| {
        swapchainImageBase[i] = @ptrCast(buf);
    }

    // Keep the buffer alive by moving it into the list of buffers.
    try m_swapchainImageBuffers.append(allocator, swapchainImageBuffer);
}

pub fn GetSupportedSwapchainSampleCount(_: *const c.XrViewConfigurationView) u32 {
    return 1;
}
