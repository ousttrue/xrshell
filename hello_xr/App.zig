const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;

allocator: std.mem.Allocator,
instance: xrs.Instance,
session: xrs.Session,
action: xrs.Action,
stereo_view: xrs.StereoView,
projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{},
view_config_type: c.XrViewConfigurationType,
blend_mode: c.XrEnvironmentBlendMode,
isSessionRunning: bool = false,

pub fn init(
    allocator: std.mem.Allocator,
    gfx_extensions: []const [*:0]const u8,
    requirements: *const fn (instance: c.XrInstance, systemId: c.XrSystemId) XrError!void,
    instance_create_info: ?*const anyopaque,
    form_factor: c.XrFormFactor,
    view_config_type: c.XrViewConfigurationType,
    gfx_binding: *const c.XrBaseInStructure,
    sample_count: u32,
    app_space: xrs.ReferenceSpaceType,
) !@This() {
    const instance = try xrs.Instance.init(allocator, .{
        .gfx_extensions = gfx_extensions,
        .form_factor = form_factor,
        .instance_create_info = instance_create_info,
    });

    const blend_mode = try instance.getPreferredBlendMode(view_config_type);
    try instance.logViewConfigurations(view_config_type, blend_mode);

    try requirements(instance.instance, instance.systemId);

    const session = try xrs.Session.init(
        allocator,
        instance.instance,
        instance.systemId,
        gfx_binding,
        app_space,
    );

    const action = try xrs.Action.init(allocator, instance.instance, session.session);

    const stereo_view = try xrs.StereoView.init(
        allocator,
        instance.instance,
        instance.systemId,
        session.session,
        view_config_type,
        session.swapchainFormats,
        sample_count,
    );

    return .{
        .allocator = allocator,
        .instance = instance,
        .session = session,
        .action = action,
        .stereo_view = stereo_view,
        .view_config_type = view_config_type,
        .blend_mode = blend_mode,
    };
}

pub fn deinit(this: *@This()) void {
    this.projectionLayerViews.deinit(this.allocator);

    this.stereo_view.deinit();
    this.action.deinit();
    this.session.deinit();
    this.instance.deinit();
}

pub fn run_frame(this: *@This(), renderer: anytype) !enum {
    next,
    quit,
} {
    switch (try this.instance.pollEvents()) {
        .quit => {
            return .quit;
        },
        .restart => {
            return .quit;
        },
        .next => {
            if (this.isSessionRunning) {
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
                            const color_texture = this.stereo_view.getTexture(i, acquired.swapchainImageIndex);
                            try renderer.renderView(
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
            this.isSessionRunning = true;
        },
        .session_end => {
            try this.session.end();
            this.isSessionRunning = false;
        },
    }

    return .next;
}
