const std = @import("std");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const Window = @import("window/WindowAndroidOpenGLES.zig");
const binding = @import("gfx/graphicsplugin_opengles.zig").binding;
const Renderer = @import("gfx/RendererOpenGLES.zig");
const App = @import("App.zig");
const android_logger = @import("android/android_logger.zig");

pub const std_options: std.Options = .{
    .logFn = android_logger.logFn,
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
        binding.getSupportedSwapchainSampleCount(),
        options.AppSpace,
    ) catch @panic("App.init");
    defer xr_app.deinit();

    var renderer: Renderer = .init(allocator);
    defer renderer.deinit();

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

        const next = xr_app.run_frame(&renderer) catch @panic("run_frame");
        switch (next) {
            .next => continue,
            .quit => break,
        }
    }

    // app.activity.vm.DetachCurrentThread();
}
