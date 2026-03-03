const std = @import("std");
const c = @import("gfx/gfxwrapper_opengl_wayland.zig").c;
const xr_result = @import("xr_result.zig");

pub fn to_string(res: c.XrResult) []const u8 {
    const e: xr_result.XrResult = @enumFromInt(res);
    return @tagName(e);
}

pub fn ThrowXrResult(res: c.XrResult, sourceLocation: std.builtin.SourceLocation) void {
    std.log.err("XrResult failure [{s}] {}", .{ to_string(res), sourceLocation });
    @panic("");
}

pub fn CheckXrResult(res: c.XrResult, originator: []const u8, sourceLocation: []const u8) c.XrResult {
    if (c.XR_FAILED(res)) {
        ThrowXrResult(res, originator, sourceLocation);
    }

    return res;
}

pub fn CHECK_XRCMD(sourceLocation: std.builtin.SourceLocation, res: c.XrResult) void {
    if (c.XR_FAILED(res)) {
        ThrowXrResult(res, sourceLocation);
    }
}
