const std = @import("std");
const Options = @import("Options.zig");
const OpenXrProgram = @import("OpenXrProgram.zig");

// #if defined(_WIN32)
// // Favor the high performance NVIDIA or AMD GPUs
// extern "C" {
// // http://developer.download.nvidia.com/devzone/devcenter/gamegraphics/files/OptimusRenderingPolicies.pdf
// __declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
// // https://gpuopen.com/learn/amdpowerxpressrequesthighperformance/
// __declspec(dllexport) DWORD AmdPowerXpressRequestHighPerformance = 0x00000001;
// }
// #endif  // defined(_WIN32)

var quitKeyPressed = false;

fn GetKey() void {
    std.log.info("Press any key to shutdown...", .{});
    var buf: [1]u8 = undefined;
    var r = std.fs.File.stdin().reader(&buf);
    var tmp: [1]u8 = undefined;
    r.interface.readSliceAll(&tmp) catch {
        //
    };
    quitKeyPressed = true;
}

pub fn main() !void {
    // const allocator = std.heap.c_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var options: Options = .{};

    if (!options.UpdateOptionsFromCommandLine(std.os.argv)) {
        return;
    }

    // Spawn a thread to wait for a keypress
    const thread = try std.Thread.spawn(.{}, GetKey, .{});
    defer thread.join();

    // const requestRestart = true;
    // while (!quitKeyPressed)
    {
        // Initialize the OpenXR program.
        // XR_PLATFORM_UpdateOptions(options);
        // XR_GFX_UpdateOptions(options);
        OpenXrProgram.init(&options);

        try OpenXrProgram.CreateInstance(allocator);
        //             XR_PROG_InitializeSystem();
        //
        //             SetEnvironmentBlendMode(&options, XR_PROG_GetPreferredBlendMode());
        //             UpdateOptionsFromCommandLine(&options, argc, argv);
        //
        //             XR_PROG_InitializeDevice();
        //             XR_PROG_InitializeSession();
        //             XR_PROG_CreateSwapchains();
        //
        //             while (!quitKeyPressed) {
        //                 bool exitRenderLoop = false;
        //                 XR_PROG_PollEvents(&exitRenderLoop, &requestRestart);
        //                 if (exitRenderLoop) {
        //                     break;
        //                 }
        //
        //                 if (XR_PROG_IsSessionRunning()) {
        //                     XR_PROG_PollActions();
        //                     XR_PROG_RenderFrame();
        //                 } else {
        //                     // Throttle loop since xrWaitFrame won't be called.
        //                     std::this_thread::sleep_for(std::chrono::milliseconds(250));
        //                 }
        //             }
    }

    //         return 0;
    //     } catch (const std::exception& ex) {
    //         Log::Write(Log::Level::Error, ex.what());
    //         return 1;
    //     } catch (...) {
    //         Log::Write(Log::Level::Error, "Unknown Error");
    //         return 1;
    //     }
}
