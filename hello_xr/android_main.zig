const std = @import("std");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const Window = @import("window/WindowAndroidOpenGLES.zig");
const binding = @import("gfx/graphicsplugin_opengles.zig").binding;
const App = @import("App.zig");
const Renderer = @import("gfx/OpenGLRenderer.zig");
const shaders = @import("gfx/shaders.zig");

pub const std_options: std.Options = .{
    .logFn = @import("android/android_logger.zig").logFn,
    .log_level = .debug,
};

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

    var renderer: Renderer = .init(allocator, shaders.es3.vs, shaders.es3.fs);
    defer renderer.deinit();

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

    std.log.warn("New instance", .{});

    var xr_app = App.init(
        allocator,
        &binding.extensions,
        &binding.requirements,
        &instanceCreateInfoAndroid,
        options.FormFactor,
        options.ViewConfigType,
        @ptrCast(&binding.makeBinding(window.context)),
    ) catch @panic("App.init");
    defer xr_app.deinit();

    var action = xrs.Action.init(
        allocator,
        xr_app.instance.instance,
        xr_app.session.session,
    ) catch @panic("Action.init");
    defer action.deinit();

    var stereo_view = xrs.StereoView.init(
        allocator,
        xr_app.instance.instance,
        xr_app.instance.systemId,
        xr_app.session.session,
        xr_app.session.swapchainFormats,
        c.GL_DEPTH_COMPONENT24,
        binding.getSupportedSwapchainSampleCount(),
        options.ViewConfigType,
        options.AppSpace,
    ) catch @panic("StereoView.init");
    defer stereo_view.deinit();

    std.log.warn("Loop start", .{});
    while (app.destroyRequested == 0) {
        // Read all pending events.
        while (true) {
            var events: c_int = undefined;
            var source: ?*c.android_poll_source = null;
            // If the timeout is zero, returns immediately without blocking.
            // If the timeout is negative, waits indefinitely until an event appears.
            const timeoutMilliseconds: c_int = if (!appState.Resumed and !xr_app.isSessionRunning and app.destroyRequested == 0) -1 else 0;
            if (c.ALooper_pollAll(timeoutMilliseconds, null, &events, @ptrCast(&source)) < 0) {
                break;
            }

            // Process this event.
            if (source) |p| {
                c.call_source_process(app, p);
            }
        }

        const next = xr_app.run_frame() catch @panic("run_frame");
        switch (next) {
            .next => continue,
            .quit => break,
            .restart => break,
            .render => {
                // begin frame
                const frameState = stereo_view.beginFrame() catch @panic("beginFrame");

                // scene
                action.pollActions() catch @panic("pollActions");
                const cubes = action.update(
                    stereo_view.space,
                    frameState.predictedDisplayTime,
                ) catch @panic("action.update");

                var layer_projection = stereo_view.renderProjectionLayer(
                    frameState,
                    &renderer,
                    .OPENGL,
                    cubes,
                ) catch @panic("renderProjectionLayer");

                // composition !
                stereo_view.endFrame(
                    frameState.predictedDisplayTime,
                    stereo_view.blend_mode,
                    if (layer_projection) |*l|
                        @ptrCast(l)
                    else
                        null,
                ) catch @panic("endFrame");
            },
        }
    }

    // app.activity.vm.DetachCurrentThread();
}
