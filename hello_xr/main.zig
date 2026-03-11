const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
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

    const options: xrs.Options = try .init(std.os.argv);

    const window = Window.create(allocator);
    defer window.destroy();

    while (!quit_key.quitKeyPressed) {
        std.log.warn("New instance", .{});

        var app: App = try .init(
            allocator,
            &gfx.extensions,
            options.FormFactor,
            options.ViewConfigType,
            gfx.makeBinding(window.context),
            options.AppSpace,
        );
        defer app.deinit();
        const next = try app.run(&quit_key.quitKeyPressed);
        switch (next) {
            .quit => break,
            .restart => continue,
        }
    }
}

const App = struct {
    allocator: std.mem.Allocator,
    instance: xrs.Instance,
    session: xrs.Session,
    action: xrs.Action,
    stereo_view: xrs.StereoView,
    swapchainImageBuffers: std.ArrayList([]@TypeOf(gfx.swapchain_image)) = .{},
    swapchainImages: std.ArrayList([]*c.XrSwapchainImageBaseHeader) = .{},
    projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{},
    renderer: Renderer,
    view_config_type: c.XrViewConfigurationType,
    blend_mode: c.XrEnvironmentBlendMode,

    fn init(
        allocator: std.mem.Allocator,
        gfx_extensions: []const [*:0]const u8,
        form_factor: c.XrFormFactor,
        view_config_type: c.XrViewConfigurationType,
        gfx_binding: gfx.Binding,
        app_space: xrs.ReferenceSpaceType,
    ) !@This() {
        const instance = try xrs.Instance.init(allocator, .{
            .gfx_extensions = gfx_extensions,
            .form_factor = form_factor,
        });

        const blend_mode = try instance.getPreferredBlendMode(view_config_type);
        try instance.logViewConfigurations(view_config_type, blend_mode);

        try gfx.requirements(instance.instance, instance.systemId);

        const session = try xrs.Session.init(
            allocator,
            instance.instance,
            instance.systemId,
            @ptrCast(&gfx_binding),
            app_space,
        );

        // Select a swapchain format.
        const colorSwapchainFormat = try gfx.selectColorSwapchainFormat(allocator, session.swapchainFormats);

        const action = try xrs.Action.init(allocator, instance.instance, session.session);

        const stereo_view = try xrs.StereoView.init(
            allocator,
            instance.instance,
            instance.systemId,
            session.session,
            view_config_type,
            colorSwapchainFormat,
            gfx.getSupportedSwapchainSampleCount(),
        );

        const renderer: Renderer = .init(allocator);

        var this: @This() = .{
            .allocator = allocator,
            .instance = instance,
            .session = session,
            .action = action,
            .stereo_view = stereo_view,
            .renderer = renderer,
            .view_config_type = view_config_type,
            .blend_mode = blend_mode,
        };
        this.logFormats(colorSwapchainFormat);
        try this.makeSwapchain();

        return this;
    }

    fn deinit(this: *@This()) void {
        this.renderer.deinit();
        this.projectionLayerViews.deinit(this.allocator);
        for (this.swapchainImageBuffers.items) |image| {
            this.allocator.free(image);
        }
        this.swapchainImageBuffers.deinit(this.allocator);
        for (this.swapchainImages.items) |image| {
            this.allocator.free(image);
        }
        this.swapchainImages.deinit(this.allocator);

        this.stereo_view.deinit();
        this.action.deinit();
        this.session.deinit();
        this.instance.deinit();
    }

    fn makeSwapchain(this: *@This()) !void {
        for (this.stereo_view.swapchains.items) |swapchain| {
            var imageCount: u32 = undefined;
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, 0, &imageCount, null));
            const swapchainImageBuffer = try this.allocator.alloc(@TypeOf(gfx.swapchain_image), imageCount);
            const swapchainImageBase = try this.allocator.alloc(*c.XrSwapchainImageBaseHeader, imageCount);
            for (swapchainImageBase, swapchainImageBuffer) |*base, *buf| {
                base.* = @ptrCast(buf);
                buf.* = gfx.swapchain_image;
            }
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(
                swapchain.handle,
                @intCast(swapchainImageBuffer.len),
                &imageCount,
                @ptrCast(swapchainImageBuffer.ptr),
            ));
            // Keep the buffer alive
            try this.swapchainImages.append(this.allocator, swapchainImageBase);
            try this.swapchainImageBuffers.append(this.allocator, swapchainImageBuffer);
        }
    }

    // Print swapchain formats and the selected one.
    fn logFormats(
        this: *const @This(),
        colorSwapchainFormat: i64,
    ) void {
        // const swapchainFormatsString: []const u8 = "";
        var out = std.Io.Writer.Allocating.init(this.allocator);
        defer out.deinit();
        // std.io.Writer を値渡しすると壊れる
        var w: *std.io.Writer = &out.writer;

        for (this.session.swapchainFormats) |format| {
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
        defer this.allocator.free(str);
        std.log.debug("Swapchain Formats: {s}", .{str});
    }

    fn run(
        this: *@This(),
        quit_key: *const bool,
    ) !enum {
        quit,
        restart,
    } {
        var isSessionRunning = false;
        std.log.warn("Loop start", .{});
        while (!quit_key.*) {
            switch (try this.instance.pollEvents()) {
                .quit => {
                    break;
                },
                .restart => {
                    return .restart;
                },
                .next => {
                    if (isSessionRunning) {
                        try this.action.pollActions();
                        //
                        // begin frame !
                        //
                        const frameState = try this.stereo_view.beginFrame();
                        var layer_projection: ?c.XrCompositionLayerProjection = null;
                        if (frameState.shouldRender == c.XR_TRUE) {
                            if (try this.stereo_view.locate(
                                this.session.space,
                                frameState.predictedDisplayTime,
                                this.view_config_type,
                            )) {
                                // scene
                                const cubes = try this.action.update(this.session.space, frameState.predictedDisplayTime);

                                // render
                                try this.projectionLayerViews.resize(this.allocator, this.stereo_view.views.items.len);
                                for (0..this.stereo_view.swapchains.items.len) |i| {
                                    const acquired = try this.stereo_view.acquireSwapchain(i);
                                    this.projectionLayerViews.items[i] = acquired.projection_layer_view;

                                    const entry = this.swapchainImages.items[i];
                                    const swapchain_image = entry[acquired.swapchainImageIndex];
                                    const color_texture = @as(*const @TypeOf(gfx.swapchain_image), @ptrCast(swapchain_image)).image;

                                    try this.renderer.renderView(
                                        &acquired.projection_layer_view,
                                        color_texture,
                                        this.stereo_view.colorSwapchainFormat,
                                        xrs.Options.GetBackgroundClearColor(this.blend_mode),
                                        cubes,
                                    );

                                    try this.stereo_view.releaseSwapchain(acquired.handle);
                                }
                                // composition layer
                                layer_projection = .{
                                    .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
                                    .space = this.session.space,
                                    .layerFlags = if (this.blend_mode == c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND)
                                        c.XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT |
                                            c.XR_COMPOSITION_LAYER_UNPREMULTIPLIED_ALPHA_BIT
                                    else
                                        0,
                                    .viewCount = @intCast(this.projectionLayerViews.items.len),
                                    .views = this.projectionLayerViews.items.ptr,
                                };
                            }
                        }
                        // composition !
                        try this.stereo_view.endFrame(
                            frameState.predictedDisplayTime,
                            this.blend_mode,
                            if (layer_projection) |*l|
                                @ptrCast(l)
                            else
                                null,
                        );
                    } else {
                        // Throttle loop since xrWaitFrame won't be called.
                        std.Thread.sleep(std.time.ns_per_ms * 250);
                    }
                },
                .session_begin => {
                    try this.session.begin(this.view_config_type);
                    isSessionRunning = true;
                },
                .session_end => {
                    try this.session.end();
                    isSessionRunning = false;
                },
            }
        }

        return .quit;
    }
};
