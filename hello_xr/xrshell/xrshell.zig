const xr_result = @import("xr_result.zig");
pub const XrResult = xr_result.XrResult;
pub const XrError = xr_result.XrError;
pub const Instance = @import("Instance.zig");
pub const Session = @import("Session.zig");
pub const Action = @import("Action.zig");

// pub fn ThrowXrResult(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, originator: []const u8) void {
//     std.log.err("XrResult failure [{s}] {s} {}", .{ to_string(res), originator, sourceLocation });
//     @panic("");
// }
//
// pub fn CheckXrResult(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, originator: []const u8) void {
//     if (c.XR_FAILED(res)) {
//         ThrowXrResult(sourceLocation, res, originator);
//     }
// }
//
// pub fn CHECK_XRRESULT(sourceLocation: std.builtin.SourceLocation, res: c.XrResult, cmdStr: []const u8) void {
//     return CheckXrResult(sourceLocation, res, cmdStr);
// }
//
// pub fn CHECK_XRCMD(sourceLocation: std.builtin.SourceLocation, res: c.XrResult) void {
//     if (c.XR_FAILED(res)) {
//         ThrowXrResult(sourceLocation, res, "");
//     }
// }

