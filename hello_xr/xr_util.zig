const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");

pub fn to_string(res: c.XrResult) []const u8 {
    const e: xr_result.XrResult = @enumFromInt(res);
    return @tagName(e);
}

pub fn ThrowXrResult(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, originator: []const u8) void {
    std.log.err("XrResult failure [{s}] {s} {}", .{ to_string(res), originator, sourceLocation });
    @panic("");
}

pub fn CheckXrResult(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, originator: []const u8) void {
    if (c.XR_FAILED(res)) {
        ThrowXrResult(sourceLocation, res, originator);
    }
}

pub fn CHECK_XRRESULT(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, cmdStr: []const u8) void {
    return CheckXrResult(sourceLocation, res, cmdStr);
}

pub fn CHECK_XRCMD(sourceLocation: std.builtin.SourceLocation, res: c.XrResult) void {
    if (c.XR_FAILED(res)) {
        ThrowXrResult(sourceLocation, res, "");
    }
}
