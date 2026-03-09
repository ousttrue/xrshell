const std = @import("std");
const c = @import("c");
const OpenXrProgram = @import("OpenXrProgram.zig");
const action = @import("action.zig");
const Options = @import("Options.zig");

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
    const prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";

    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, prefix ++ format, args) catch {
        return;
    };

    const CSI = "\x1B[";
    const begin = switch (message_level) {
        .debug => CSI ++ "37m[Debug]",
        .info => CSI ++ "33m[Info ]",
        .warn => CSI ++ "35m[Warn ]",
        .err => CSI ++ "31m[Error]",
    };
    std.debug.print("{s}{s}{s}0m\n", .{ begin, msg, CSI });
}

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

        try OpenXrProgram.CreateInstance(allocator, null);
        try OpenXrProgram.InitializeSystem();

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
                try action.PollActions(session);
                // try OpenXrProgram.oRenderFrame(allocator);
                const frameState = try OpenXrProgram.beginFrame();
                var layer: ?*c.XrCompositionLayerBaseHeader = null;
                if (frameState.shouldRender == c.XR_TRUE) {
                    if (try OpenXrProgram.locate(frameState.predictedDisplayTime)) {
                        layer = try OpenXrProgram.RenderLayer(
                            allocator,
                            frameState.predictedDisplayTime,
                        );
                    }
                }
                try OpenXrProgram.endFrame(frameState.predictedDisplayTime, layer);
            } else {
                // Throttle loop since xrWaitFrame won't be called.
                std.Thread.sleep(std.time.ns_per_ms * 250);
            }
        }
    }
}
