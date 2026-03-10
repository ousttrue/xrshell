const std = @import("std");

thread: ?std.Thread = null,
quitKeyPressed: bool = false,

pub fn deinit(this: *@This()) void {
    if (this.thread) |thread| {
        defer thread.join();
    }
}

pub fn spawn(this: *@This()) !void {
    std.debug.assert(this.thread == null);
    this.thread = try std.Thread.spawn(.{}, gets, .{this});
}

pub fn gets(this: *@This()) void {
    std.log.info("Press any key to shutdown...", .{});
    var buf: [1]u8 = undefined;
    var r = std.fs.File.stdin().reader(&buf);
    var tmp: [1]u8 = undefined;
    r.interface.readSliceAll(&tmp) catch {
        //
    };
    this.quitKeyPressed = true;
}
