const std = @import("std");
const c = @import("c");

// void ShowHelp() {
//     Log::Write(Log::Level::Info, "adb shell setprop debug.xr.graphicsPlugin OpenGLES|Vulkan");
//     Log::Write(Log::Level::Info, "adb shell setprop debug.xr.formFactor Hmd|Handheld");
//     Log::Write(Log::Level::Info, "adb shell setprop debug.xr.viewConfiguration Stereo|Mono");
//     Log::Write(Log::Level::Info, "adb shell setprop debug.xr.blendMode Opaque|Additive|AlphaBlend");
// }
//
// bool UpdateOptionsFromSystemProperties(Options& options) {
// #if defined(DEFAULT_GRAPHICS_PLUGIN_OPENGLES)
//     options.GraphicsPlugin = "OpenGLES";
// #elif defined(DEFAULT_GRAPHICS_PLUGIN_VULKAN)
//     options.GraphicsPlugin = "Vulkan";
// #endif
//
//     char value[PROP_VALUE_MAX] = {};
//     if (__system_property_get("debug.xr.graphicsPlugin", value) != 0) {
//         options.GraphicsPlugin = value;
//     }
//
//     if (__system_property_get("debug.xr.formFactor", value) != 0) {
//         options.FormFactor = value;
//     }
//
//     if (__system_property_get("debug.xr.viewConfiguration", value) != 0) {
//         options.ViewConfiguration = value;
//     }
//
//     if (__system_property_get("debug.xr.blendMode", value) != 0) {
//         options.EnvironmentBlendMode = value;
//     }
//
//     try {
//         options.ParseStrings();
//     } catch (std::invalid_argument& ia) {
//         Log::Write(Log::Level::Error, ia.what());
//         ShowHelp();
//         return false;
//     }
//     return true;
// }
//
// #ifdef XR_USE_PLATFORM_ANDROID

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
            //             Log::Write(Log::Level::Info, "    APP_CMD_START");
            //             Log::Write(Log::Level::Info, "onStart()");
        },
        c.APP_CMD_RESUME => {
            //             Log::Write(Log::Level::Info, "onResume()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_RESUME");
            //             appState.Resumed = true;
        },
        c.APP_CMD_PAUSE => {
            //             Log::Write(Log::Level::Info, "onPause()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_PAUSE");
            //             appState.Resumed = false;
        },
        c.APP_CMD_STOP => {
            //             Log::Write(Log::Level::Info, "onStop()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_STOP");
        },
        c.APP_CMD_DESTROY => {
            //             Log::Write(Log::Level::Info, "onDestroy()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_DESTROY");
            //             appState.NativeWindow = NULL;
        },
        c.APP_CMD_INIT_WINDOW => {
            //             Log::Write(Log::Level::Info, "surfaceCreated()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_INIT_WINDOW");
            appState.NativeWindow = app.*.window;
        },
        c.APP_CMD_TERM_WINDOW => {
            //             Log::Write(Log::Level::Info, "surfaceDestroyed()");
            //             Log::Write(Log::Level::Info, "    APP_CMD_TERM_WINDOW");
            //             appState.NativeWindow = NULL;
        },
        else => {},
    }
}

// This is the main entry point of a native application that is using
// android_native_app_glue.  It runs in its own thread, with its own
// event loop for receiving input events and doing other things.
export fn android_main(app: *c.android_app) void {
    //     try {
    //         JNIEnv* Env;
    //         app.activity.vm.AttachCurrentThread(&Env, null);

    var appState: AndroidAppState = .{};
    app.userData = &appState;
    app.onAppCmd = app_handle_cmd;

    //         std::shared_ptr<Options> options = std::make_shared<Options>();
    //         if (!UpdateOptionsFromSystemProperties(*options)) {
    //             return;
    //         }
    //
    //         std::shared_ptr<PlatformData> data = std::make_shared<PlatformData>();
    //         data.applicationVM = app.activity.vm;
    //         data.applicationActivity = app.activity.clazz;
    //
    //         bool requestRestart = false;
    //         bool exitRenderLoop = false;
    //
    //         // Create platform-specific implementation.
    //         std::shared_ptr<IPlatformPlugin> platformPlugin = CreatePlatformPlugin(options, data);
    //         // Create graphics API implementation.
    //         std::shared_ptr<IGraphicsPlugin> graphicsPlugin = CreateGraphicsPlugin(options, platformPlugin);
    //
    //         // Initialize the OpenXR program.
    //         std::shared_ptr<IOpenXrProgram> program = CreateOpenXrProgram(options, platformPlugin, graphicsPlugin);
    //
    //         // Initialize the loader for this platform
    //         PFN_xrInitializeLoaderKHR initializeLoader = null;
    //         if (XR_SUCCEEDED(
    //                 xrGetInstanceProcAddr(XR_NULL_HANDLE, "xrInitializeLoaderKHR", (PFN_xrVoidFunction*)(&initializeLoader)))) {
    //             XrLoaderInitInfoAndroidKHR loaderInitInfoAndroid = {XR_TYPE_LOADER_INIT_INFO_ANDROID_KHR};
    //             loaderInitInfoAndroid.applicationVM = app.activity.vm;
    //             loaderInitInfoAndroid.applicationContext = app.activity.clazz;
    //             initializeLoader((const XrLoaderInitInfoBaseHeaderKHR*)&loaderInitInfoAndroid);
    //         }
    //
    //         program.CreateInstance();
    //         program.InitializeSystem();
    //
    //         options.SetEnvironmentBlendMode(program.GetPreferredBlendMode());
    //         UpdateOptionsFromSystemProperties(*options);
    //         platformPlugin.UpdateOptions(options);
    //         graphicsPlugin.UpdateOptions(options);
    //
    //         program.InitializeDevice();
    //         program.InitializeSession();
    //         program.CreateSwapchains();
    //
    //         while (app.destroyRequested == 0) {
    //             // Read all pending events.
    //             for (;;) {
    //                 int events;
    //                 struct android_poll_source* source;
    //                 // If the timeout is zero, returns immediately without blocking.
    //                 // If the timeout is negative, waits indefinitely until an event appears.
    //                 const int timeoutMilliseconds =
    //                     (!appState.Resumed && !program.IsSessionRunning() && app.destroyRequested == 0) ? -1 : 0;
    //                 if (ALooper_pollAll(timeoutMilliseconds, null, &events, (void**)&source) < 0) {
    //                     break;
    //                 }
    //
    //                 // Process this event.
    //                 if (source != null) {
    //                     source.process(app, source);
    //                 }
    //             }
    //
    //             program.PollEvents(&exitRenderLoop, &requestRestart);
    //             if (exitRenderLoop) {
    //                 ANativeActivity_finish(app.activity);
    //                 continue;
    //             }
    //
    //             if (!program.IsSessionRunning()) {
    //                 // Throttle loop since xrWaitFrame won't be called.
    //                 std::this_thread::sleep_for(std::chrono::milliseconds(250));
    //                 continue;
    //             }
    //
    //             program.PollActions();
    //             program.RenderFrame();
    //         }
    //
    //         app.activity.vm.DetachCurrentThread();
    //     } catch (const std::exception& ex) {
    //         Log::Write(Log::Level::Error, ex.what());
    //     } catch (...) {
    //         Log::Write(Log::Level::Error, "Unknown Error");
    //     }
}
