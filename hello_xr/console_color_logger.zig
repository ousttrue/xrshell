const std = @import("std");

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
