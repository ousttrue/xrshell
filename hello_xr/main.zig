const std = @import("std");
const OpenXrProgram = @import("OpenXrProgram.zig");
const action = @import("action.zig");
const binding = @import("binding.zig");
const Options = binding.Options;

var quitKeyPressed = false;

fn gets() void {
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
    const thread = try std.Thread.spawn(.{}, gets, .{});
    defer thread.join();

    var requestRestart = true;
    while (!quitKeyPressed and requestRestart) {
        OpenXrProgram.init(allocator, &options);
        defer OpenXrProgram.deinit(allocator);

        try OpenXrProgram.CreateInstance(allocator);
        OpenXrProgram.InitializeSystem();

        options.SetEnvironmentBlendMode(try OpenXrProgram.GetPreferredBlendMode(allocator));

        try OpenXrProgram.InitializeDevice(allocator);
        const session = try OpenXrProgram.InitializeSession(allocator);
        try OpenXrProgram.CreateSwapchains(allocator);

        while (!quitKeyPressed) {
            var exitRenderLoop = false;
            try OpenXrProgram.PollEvents(allocator, &exitRenderLoop, &requestRestart);
            if (exitRenderLoop) {
                break;
            }

            if (OpenXrProgram.IsSessionRunning()) {
                action.PollActions(session);
                try OpenXrProgram.RenderFrame(allocator);
            } else {
                // Throttle loop since xrWaitFrame won't be called.
                std.Thread.sleep(std.time.ns_per_ms * 250);
            }
        }
    }
}
