const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const OpenXrProgram = @import("OpenXrProgram.zig");
const Options = @import("Options.zig");
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const Window = @import("window/window.zig").Window;
const Renderer = @import("gfx/RendererOpenGL4.zig");

pub const std_options: std.Options = .{
    .logFn = console_color_logger.logFn,
    .log_level = .debug,
};

pub fn main() !void {
    // Spawn a thread to wait for a keypress
    var quit_key: QuitKeyObserver = .{};
    try quit_key.spawn();
    defer quit_key.deinit();

    // const allocator = std.heap.c_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const options: Options = try .init(std.os.argv);

    const gfx_extensions = [_][*:0]const u8{
        c.XR_KHR_OPENGL_ENABLE_EXTENSION_NAME,
    };
    const window = Window.create(allocator);
    defer window.destroy();
    var gfx_binding: c.XrGraphicsBindingOpenGLWin32KHR = .{
        .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR,
        .hDC = window.context.hDC,
        .hGLRC = window.context.hGLRC,
    };

    while (!quit_key.quitKeyPressed) {
        std.log.warn("New instance", .{});

        const next = try run_instance(
            allocator,
            &quit_key.quitKeyPressed,
            options.FormFactor,
            options.ViewConfigType,
            options.AppSpace,
            &gfx_extensions,
            @ptrCast(&gfx_binding),
        );
        switch (next) {
            .quit => break,
            .restart => continue,
        }
    }
}

fn run_instance(
    allocator: std.mem.Allocator,
    quit_key: *const bool,
    form_factor: c.XrFormFactor,
    view_config_type: c.XrViewConfigurationType,
    app_space: Options.ReferenceSpaceType,
    gfx_extensions: []const [*:0]const u8,
    gfx_binding: *c.XrBaseInStructure,
) !enum {
    quit,
    restart,
} {
    var instance = try xrs.Instance.init(allocator, .{
        .gfx_extensions = gfx_extensions,
        .form_factor = form_factor,
    });
    defer instance.deinit();
    const blend_mode = try instance.getPreferredBlendMode(view_config_type);
    try instance.logViewConfigurations(view_config_type, blend_mode);

    var session = try xrs.Session.init(
        allocator,
        instance.instance,
        instance.systemId,
        gfx_binding,
    );
    defer session.deinit();

    // Select a swapchain format.
    const colorSwapchainFormat = try gfx.SelectColorSwapchainFormat(allocator, session.swapchainFormats);
    // Print swapchain formats and the selected one.
    {
        // const swapchainFormatsString: []const u8 = "";
        var out = std.Io.Writer.Allocating.init(allocator);
        defer out.deinit();
        // std.io.Writer を値渡しすると壊れる
        var w: *std.io.Writer = &out.writer;

        for (session.swapchainFormats) |format| {
            const selected = format == colorSwapchainFormat;
            w.writeAll(" ") catch @panic("OOM");
            if (selected) {
                w.writeAll("[") catch @panic("OOM");
            }
            w.print("{}", .{format}) catch @panic("OM");
            if (selected) {
                w.writeAll("]") catch @panic("OOM");
            }
        }
        const str = out.toOwnedSlice() catch @panic("OOM");
        defer allocator.free(str);
        std.log.debug("Swapchain Formats: {s}", .{str});
    }

    var action = try xrs.Action.init(allocator, instance.instance, session.session);
    defer action.deinit();

    var prog = try OpenXrProgram.init(
        allocator,
        instance.instance,
        instance.systemId,
        session.session,
        view_config_type,
        colorSwapchainFormat,
        gfx.GetSupportedSwapchainSampleCount(),
        app_space,
    );
    defer prog.deinit();
    var swapchainImageBuffers: std.ArrayList([]@TypeOf(gfx.swapchain_image)) = .{};
    var swapchainImages: std.ArrayList([]*c.XrSwapchainImageBaseHeader) = .{};
    defer {
        for (swapchainImageBuffers.items) |image| {
            allocator.free(image);
        }
        swapchainImageBuffers.deinit(allocator);
        for (swapchainImages.items) |image| {
            allocator.free(image);
        }
        swapchainImages.deinit(allocator);
    }
    for (prog.swapchains.items) |swapchain| {
        var imageCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, 0, &imageCount, null));

        const swapchainImageBase = try allocator.alloc(*c.XrSwapchainImageBaseHeader, imageCount);
        const swapchainImageBuffer = try allocator.alloc(@TypeOf(gfx.swapchain_image), imageCount);
        for (swapchainImageBase, swapchainImageBuffer) |*base, *buf| {
            base.* = @ptrCast(buf);
            buf.* = gfx.swapchain_image;
        }

        _ = try XrResult.init(c.xrEnumerateSwapchainImages(
            swapchain.handle,
            imageCount,
            &imageCount,
            swapchainImageBase[0],
        ));
        // Keep the buffer alive by moving it into the list of buffers.
        try swapchainImages.append(allocator, swapchainImageBase);
        try swapchainImageBuffers.append(allocator, swapchainImageBuffer);
    }

    var projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{};
    defer projectionLayerViews.deinit(allocator);

    // renderer
    var renderer: Renderer = .init(allocator);
    defer renderer.deinit();

    var isSessionRunning = false;
    std.log.warn("Loop start", .{});
    while (!quit_key.*) {
        switch (try instance.pollEvents()) {
            .quit => {
                break;
            },
            .restart => {
                return .restart;
            },
            .next => {
                if (isSessionRunning) {
                    try action.pollActions();
                    //
                    // begin frame !
                    //
                    const frameState = try prog.beginFrame();
                    var layer: ?c.XrCompositionLayerProjection = null;
                    if (frameState.shouldRender == c.XR_TRUE) {
                        if (try prog.locate(frameState.predictedDisplayTime, view_config_type)) {
                            //
                            // render
                            //
                            const cubes = try action.update(prog.appSpace, frameState.predictedDisplayTime);
                            try projectionLayerViews.resize(allocator, prog.views.items.len);
                            for (0..prog.swapchains.items.len) |i| {
                                const acquired = try prog.acquireSwapchain(i);
                                projectionLayerViews.items[i] = acquired.projection_layer_view;

                                const entry = swapchainImages.items[i];
                                const swapchain_image = entry[acquired.swapchainImageIndex];

                                try renderer.renderView(
                                    &acquired.projection_layer_view,
                                    swapchain_image,
                                    prog.colorSwapchainFormat,
                                    Options.GetBackgroundClearColor(blend_mode),
                                    cubes,
                                );

                                try prog.releaseSwapchain(acquired.handle);
                            }
                            // composition layer
                            layer = .{
                                .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
                                .space = prog.appSpace,
                                .layerFlags = if (blend_mode == c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND)
                                    c.XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT |
                                        c.XR_COMPOSITION_LAYER_UNPREMULTIPLIED_ALPHA_BIT
                                else
                                    0,
                                .viewCount = @intCast(projectionLayerViews.items.len),
                                .views = projectionLayerViews.items.ptr,
                            };
                        }
                    }
                    // composition !
                    try prog.endFrame(frameState.predictedDisplayTime, blend_mode, if (layer) |*l|
                        @ptrCast(l)
                    else
                        null);
                } else {
                    // Throttle loop since xrWaitFrame won't be called.
                    std.Thread.sleep(std.time.ns_per_ms * 250);
                }
            },
            .session_begin => {
                try session.begin(view_config_type);
                isSessionRunning = true;
            },
            .session_end => {
                try session.end();
                isSessionRunning = false;
            },
        }
    }

    return .quit;
}
