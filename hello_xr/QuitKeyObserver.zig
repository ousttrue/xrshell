const std = @import("std");

thread: ?std.Thread = null,
quitKeyPressed: bool = false,

pub fn deinit(this: *@This()) void {
    if (this.thread) |thread| {
        defer thread.join();
    }
}

/// Spawn a thread to wait for a keypress
pub fn spawn(this: *@This()) !void {
    std.log.info("[QuitKeyObserver] Press [enter] to shutdown...", .{});
    std.debug.assert(this.thread == null);
    this.thread = try std.Thread.spawn(.{}, gets, .{this});
}

pub fn gets(this: *@This()) void {
    var buf: [1]u8 = undefined;
    var r = std.fs.File.stdin().reader(&buf);
    var tmp: [1]u8 = undefined;
    r.interface.readSliceAll(&tmp) catch {
        //
    };

    std.log.warn("[QuitKeyObserver] Press [enter]. Quit !", .{});

    this.quitKeyPressed = true;
}
