const std = @import("std");
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

    const CSI = "\x1B[";
    const begin = switch (message_level) {
        .debug => CSI ++ "37m",
        .info => CSI ++ "33m",
        .warn => CSI ++ "35m",
        .err => CSI ++ "31m",
    };

    std.debug.print("{s}{s}{s}0m\n", .{ begin, &buf.buffer, CSI });
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
                try OpenXrProgram.RenderFrame(allocator);
            } else {
                // Throttle loop since xrWaitFrame won't be called.
                std.Thread.sleep(std.time.ns_per_ms * 250);
            }
        }
    }
}
