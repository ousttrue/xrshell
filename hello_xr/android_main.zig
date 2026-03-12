const std = @import("std");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const Window = @import("window/WindowAndroidOpenGLES.zig");
const gfx = @import("gfx/graphicsplugin_opengles.zig");
const Renderer = @import("gfx/RendererOpenGL4.zig");

pub const std_options: std.Options = .{
    .logFn = logFn,
    .log_level = .debug,
};

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const priority = switch (message_level) {
        .err => c.ANDROID_LOG_ERROR,
        .warn => c.ANDROID_LOG_WARN,
        .info => c.ANDROID_LOG_INFO,
        .debug => c.ANDROID_LOG_DEBUG,
    };
    const prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";

    var buf = std.io.FixedBufferStream([4 * 1024]u8){
        .buffer = undefined,
        .pos = 0,
    };
    var writer = buf.writer();
    writer.print(prefix ++ format, args) catch {};

    if (buf.pos >= buf.buffer.len) {
        buf.pos = buf.buffer.len - 1;
    }
    buf.buffer[buf.pos] = 0;

    _ = c.__android_log_write(priority, "hello_xr", &buf.buffer);
}

fn ShowHelp() void {
    std.log.info("adb shell setprop debug.xr.graphicsPlugin OpenGLES|Vulkan", .{});
    std.log.info("adb shell setprop debug.xr.formFactor Hmd|Handheld", .{});
    std.log.info("adb shell setprop debug.xr.viewConfiguration Stereo|Mono", .{});
    std.log.info("adb shell setprop debug.xr.blendMode Opaque|Additive|AlphaBlend", .{});
}

fn UpdateOptionsFromSystemProperties(options: *xrs.Options) bool {
    var value: [c.PROP_VALUE_MAX]u8 = undefined;

    if (c.__system_property_get("debug.xr.formFactor", &value) != 0) {
        options.FormFactor = xrs.Options.GetXrFormFactor(std.mem.sliceTo(&value, 0)) catch {
            return false;
        };
    }

    if (c.__system_property_get("debug.xr.viewConfiguration", &value) != 0) {
        options.ViewConfigType = xrs.Options.GetXrViewConfigurationType(std.mem.sliceTo(&value, 0)) catch {
            return false;
        };
    }

    return true;
}

const AndroidAppState = struct {
    NativeWindow: ?*c.ANativeWindow = null,
    Resumed: bool = false,
};

// Process the next main command.
export fn app_handle_cmd(app: [*c]c.android_app, cmd: c_int) void {
    const appState: *AndroidAppState = @ptrCast(@alignCast(app.*.userData));

    switch (cmd) {
        // There is no APP_CMD_CREATE. The ANativeActivity creates the
        // application thread from onCreate(). The application thread
        // then calls android_main().
        c.APP_CMD_START => {
            std.log.debug("    APP_CMD_START", .{});
            std.log.debug("onStart()", .{});
        },
        c.APP_CMD_RESUME => {
            std.log.debug("onResume()", .{});
            std.log.debug("    APP_CMD_RESUME", .{});
            appState.Resumed = true;
        },
        c.APP_CMD_PAUSE => {
            std.log.debug("onPause()", .{});
            std.log.debug("    APP_CMD_PAUSE", .{});
            appState.Resumed = false;
        },
        c.APP_CMD_STOP => {
            std.log.debug("onStop()", .{});
            std.log.debug("    APP_CMD_STOP", .{});
        },
        c.APP_CMD_DESTROY => {
            std.log.debug("onDestroy()", .{});
            std.log.debug("    APP_CMD_DESTROY", .{});
            appState.NativeWindow = null;
        },
        c.APP_CMD_INIT_WINDOW => {
            std.log.debug("surfaceCreated()", .{});
            std.log.debug("    APP_CMD_INIT_WINDOW", .{});
            appState.NativeWindow = app.*.window;
        },
        c.APP_CMD_TERM_WINDOW => {
            std.log.debug("surfaceDestroyed()", .{});
            std.log.debug("    APP_CMD_TERM_WINDOW", .{});
            appState.NativeWindow = null;
        },
        else => {},
    }
}

// This is the main entry point of a native application that is using
// android_native_app_glue.  It runs in its own thread, with its own
// event loop for receiving input events and doing other things.
export fn android_main(app: *c.android_app) void {
    std.log.info("#### android_main ####", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var appState: AndroidAppState = .{};
    app.userData = &appState;
    app.onAppCmd = app_handle_cmd;

    var options: xrs.Options = .{};
    if (!UpdateOptionsFromSystemProperties(&options)) {
        return;
    }

    var window = Window.create(allocator);
    defer window.destroy();

    // Initialize the loader for this platform
    var initializeLoader: c.PFN_xrInitializeLoaderKHR = null;
    if (c.XR_SUCCEEDED(c.xrGetInstanceProcAddr(null, "xrInitializeLoaderKHR", &initializeLoader))) {
        var loaderInitInfoAndroid: c.XrLoaderInitInfoAndroidKHR = .{
            .type = c.XR_TYPE_LOADER_INIT_INFO_ANDROID_KHR,
            .applicationVM = @ptrCast(app.activity.*.vm),
            .applicationContext = app.activity.*.clazz,
        };
        _ = initializeLoader.?(@ptrCast(&loaderInitInfoAndroid));
    }

    const instanceCreateInfoAndroid: c.XrInstanceCreateInfoAndroidKHR = .{
        .type = c.XR_TYPE_INSTANCE_CREATE_INFO_ANDROID_KHR,
        .applicationVM = @ptrCast(app.activity.*.vm),
        .applicationActivity = app.activity,
    };
    _ = instanceCreateInfoAndroid;

    // var requestRestart = false;
    // var exitRenderLoop = false;

    // // Initialize the OpenXR program.
    // OpenXrProgram.init(allocator, &options);
    // defer OpenXrProgram.deinit(allocator);

    // OpenXrProgram.CreateInstance(allocator, &instanceCreateInfoAndroid) catch @panic("OpenXrProgram.CreateInstance");
    // OpenXrProgram.InitializeSystem() catch |e| {
    //     std.log.err("InitializeSystem => {s}", .{@errorName(e)});
    //     return;
    // };
    //
    // options.SetEnvironmentBlendMode(OpenXrProgram.GetPreferredBlendMode(allocator) catch @panic("OpenXrProgram.GetPreferredBlendMode"));
    // _ = UpdateOptionsFromSystemProperties(&options);
    // // platformPlugin.UpdateOptions(options);
    // // graphicsPlugin.UpdateOptions(options);
    //
    // OpenXrProgram.InitializeDevice(allocator) catch @panic("OpenXrProgram.InitializeDevice");
    // const session = OpenXrProgram.InitializeSession(allocator) catch @panic("OpenXrProgram.InitializeSession");
    // OpenXrProgram.CreateSwapchains(allocator) catch @panic("OpenXrProgram.CreateSwapchains");
    //
    // while (app.destroyRequested == 0) {
    //     // Read all pending events.
    //     while (true) {
    //         var events: c_int = undefined;
    //         var source: ?*c.android_poll_source = null;
    //         // If the timeout is zero, returns immediately without blocking.
    //         // If the timeout is negative, waits indefinitely until an event appears.
    //         const timeoutMilliseconds: c_int = if (!appState.Resumed and !OpenXrProgram.IsSessionRunning() and app.destroyRequested == 0) -1 else 0;
    //         if (c.ALooper_pollAll(timeoutMilliseconds, null, &events, @ptrCast(&source)) < 0) {
    //             break;
    //         }
    //
    //         // Process this event.
    //         if (source) |p| {
    //             c.call_source_process(app, p);
    //         }
    //     }
    //
    //     OpenXrProgram.PollEvents(allocator, &exitRenderLoop, &requestRestart) catch @panic("OpenXrProgram.PollEvents");
    //     if (exitRenderLoop) {
    //         c.ANativeActivity_finish(app.activity);
    //         continue;
    //     }
    //
    //     if (!OpenXrProgram.IsSessionRunning()) {
    //         // Throttle loop since xrWaitFrame won't be called.
    //         std.Thread.sleep(std.time.ns_per_ms * 250);
    //         continue;
    //     }
    //
    //     action.PollActions(session) catch |e| {
    //         std.log.err("PollActions => {s}", .{@errorName(e)});
    //     };
    //     OpenXrProgram.RenderFrame(allocator) catch @panic("OpenXrProgram.RenderFrame");
    // }
    //
    // // app.activity.vm.DetachCurrentThread();
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
    isSessionRunning: bool = false,

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
        this.isSessionRunning = false;
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
                    this.isSessionRunning = true;
                },
                .session_end => {
                    try this.session.end();
                    this.isSessionRunning = false;
                },
            }
        }

        return .quit;
    }
};
