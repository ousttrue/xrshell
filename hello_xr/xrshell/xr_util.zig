const std = @import("std");
const c = @import("c");

pub fn getXrVersionString(buf: []u8, ver: c.XrVersion) []const u8 {
    return std.fmt.bufPrint(buf, "{}.{}.{}", .{
        c.XR_VERSION_MAJOR(ver),
        c.XR_VERSION_MINOR(ver),
        c.XR_VERSION_PATCH(ver),
    }) catch @panic("OOM");
}
