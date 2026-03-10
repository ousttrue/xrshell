const std = @import("std");
const c = @import("c");
const Options = @import("Options.zig");
const OpenXrProgram = @import("OpenXrProgram.zig");
const action = @import("action.zig");

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

fn UpdateOptionsFromSystemProperties(options: *Options) bool {
    options.GraphicsPlugin = .init("OpenGLES");

    var value: [c.PROP_VALUE_MAX]u8 = undefined;
    if (c.__system_property_get("debug.xr.graphicsPlugin", &value) != 0) {
        options.GraphicsPlugin = .init(std.mem.sliceTo(&value, 0));
    }

    if (c.__system_property_get("debug.xr.formFactor", &value) != 0) {
        options.FormFactor = .init(std.mem.sliceTo(&value, 0));
    }

    if (c.__system_property_get("debug.xr.viewConfiguration", &value) != 0) {
        options.ViewConfiguration = .init(std.mem.sliceTo(&value, 0));
    }

    if (c.__system_property_get("debug.xr.blendMode", &value) != 0) {
        options.EnvironmentBlendMode = .init(std.mem.sliceTo(&value, 0));
    }

    options.ParseStrings() catch |e| {
        std.log.err("{s}", .{@errorName(e)});
        ShowHelp();
        return false;
    };
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

    //     try {
    //         JNIEnv* Env;
    //         app.activity.vm.AttachCurrentThread(&Env, null);

    var appState: AndroidAppState = .{};
    app.userData = &appState;
    app.onAppCmd = app_handle_cmd;

    var options: Options = .{};
    if (!UpdateOptionsFromSystemProperties(&options)) {
        return;
    }

    //         std::shared_ptr<PlatformData> data = std::make_shared<PlatformData>();
    //         data.applicationVM = app.activity.vm;
    //         data.applicationActivity = app.activity.clazz;

    var requestRestart = false;
    var exitRenderLoop = false;

    // Create platform-specific implementation.
    //         std::shared_ptr<IPlatformPlugin> platformPlugin = CreatePlatformPlugin(options, data);
    //         // Create graphics API implementation.
    //         std::shared_ptr<IGraphicsPlugin> graphicsPlugin = CreateGraphicsPlugin(options, platformPlugin);

    // Initialize the OpenXR program.
    OpenXrProgram.init(allocator, &options);
    defer OpenXrProgram.deinit(allocator);

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

    OpenXrProgram.CreateInstance(allocator, &instanceCreateInfoAndroid) catch @panic("OpenXrProgram.CreateInstance");
    OpenXrProgram.InitializeSystem() catch |e| {
        std.log.err("InitializeSystem => {s}", .{@errorName(e)});
        return;
    };

    options.SetEnvironmentBlendMode(OpenXrProgram.GetPreferredBlendMode(allocator) catch @panic("OpenXrProgram.GetPreferredBlendMode"));
    _ = UpdateOptionsFromSystemProperties(&options);
    // platformPlugin.UpdateOptions(options);
    // graphicsPlugin.UpdateOptions(options);

    OpenXrProgram.InitializeDevice(allocator) catch @panic("OpenXrProgram.InitializeDevice");
    const session = OpenXrProgram.InitializeSession(allocator) catch @panic("OpenXrProgram.InitializeSession");
    OpenXrProgram.CreateSwapchains(allocator) catch @panic("OpenXrProgram.CreateSwapchains");

    while (app.destroyRequested == 0) {
        // Read all pending events.
        while (true) {
            var events: c_int = undefined;
            var source: ?*c.android_poll_source = null;
            // If the timeout is zero, returns immediately without blocking.
            // If the timeout is negative, waits indefinitely until an event appears.
            const timeoutMilliseconds: c_int = if (!appState.Resumed and !OpenXrProgram.IsSessionRunning() and app.destroyRequested == 0) -1 else 0;
            if (c.ALooper_pollAll(timeoutMilliseconds, null, &events, @ptrCast(&source)) < 0) {
                break;
            }

            // Process this event.
            if (source) |p| {
                c.call_source_process(app, p);
            }
        }

        OpenXrProgram.PollEvents(allocator, &exitRenderLoop, &requestRestart) catch @panic("OpenXrProgram.PollEvents");
        if (exitRenderLoop) {
            c.ANativeActivity_finish(app.activity);
            continue;
        }

        if (!OpenXrProgram.IsSessionRunning()) {
            // Throttle loop since xrWaitFrame won't be called.
            std.Thread.sleep(std.time.ns_per_ms * 250);
            continue;
        }

        action.PollActions(session) catch |e| {
            std.log.err("PollActions => {s}", .{@errorName(e)});
        };
        OpenXrProgram.RenderFrame(allocator) catch @panic("OpenXrProgram.RenderFrame");
    }

    // app.activity.vm.DetachCurrentThread();
}
