const std = @import("std");
const Options = @import("Options.zig");
const OpenXrProgram = @import("OpenXrProgram.zig");

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

    var requestRestart = true;
    while (!quitKeyPressed and requestRestart) {
        // Initialize the OpenXR program.
        OpenXrProgram.init(allocator, &options);
        defer OpenXrProgram.deinit(allocator);

        try OpenXrProgram.CreateInstance(allocator);
        OpenXrProgram.InitializeSystem();

        options.SetEnvironmentBlendMode(try OpenXrProgram.GetPreferredBlendMode(allocator));

        try OpenXrProgram.InitializeDevice(allocator);
        try OpenXrProgram.InitializeSession(allocator);
        try OpenXrProgram.CreateSwapchains(allocator);

        while (!quitKeyPressed) {
            var exitRenderLoop = false;
            OpenXrProgram.PollEvents(&exitRenderLoop, &requestRestart);
            if (exitRenderLoop) {
                break;
            }

            if (OpenXrProgram.IsSessionRunning()) {
                OpenXrProgram.PollActions();
                OpenXrProgram.RenderFrame();
            } else {
                // Throttle loop since xrWaitFrame won't be called.
                std.Thread.sleep(std.time.ns_per_ms * 250);
            }
        }
    }
}
