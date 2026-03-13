const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrResult = xr_result.XrResult;
const XrError = xr_result.XrError;
const xr_util = @import("xr_util.zig");
const xr_types = @import("xr_types.zig");

allocator: std.mem.Allocator,
session: c.XrSession = null,
swapchainFormats: []i64 = &.{},

pub fn init(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    graphics_binding: *const c.XrBaseInStructure,
) !@This() {
    std.log.info("## Session.init ##", .{});

    var this = @This(){
        .allocator = allocator,
    };

    var createInfo: c.XrSessionCreateInfo = .{
        .type = c.XR_TYPE_SESSION_CREATE_INFO,
        .next = graphics_binding, //gfx.GetGraphicsBinding(),
        .systemId = systemId,
    };
    _ = try XrResult.init(c.xrCreateSession(instance, &createInfo, &this.session));

    var swapchainFormatCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateSwapchainFormats(this.session, 0, &swapchainFormatCount, null));
    this.swapchainFormats = try this.allocator.alloc(i64, swapchainFormatCount);
    _ = try XrResult.init(c.xrEnumerateSwapchainFormats(
        this.session,
        @intCast(this.swapchainFormats.len),
        &swapchainFormatCount,
        this.swapchainFormats.ptr,
    ));

    try xr_types.ReferenceSpaceType.log(allocator, this.session);

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## Session.deinit ##", .{});

    this.allocator.free(this.swapchainFormats);
    _ = c.xrDestroySession(this.session);
}

pub fn begin(this: *@This(), view_config_type: c.XrViewConfigurationType) XrError!void {
    var sessionBeginInfo: c.XrSessionBeginInfo = .{
        .type = c.XR_TYPE_SESSION_BEGIN_INFO,
        .primaryViewConfigurationType = view_config_type,
    };
    _ = try XrResult.init(c.xrBeginSession(this.session, &sessionBeginInfo));
}

pub fn end(this: *@This()) XrError!void {
    _ = XrResult.init(c.xrEndSession(this.session)) catch @panic("xrEndSession");
}
