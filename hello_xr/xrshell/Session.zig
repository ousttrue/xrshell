const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrResult = xr_result.XrResult;
const XrError = xr_result.XrError;
const xr_util = @import("xr_util.zig");

allocator: std.mem.Allocator,
session: c.XrSession = null,

pub fn init(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    graphics_binding: *c.XrBaseInStructure,
) !@This() {
    std.log.info("## Session.init ##", .{});

    // pub fn InitializeDevice(instance: c.XrInstance, systemId: c.XrSystemId) XrError!void {
    // Extension function must be loaded by name
    var pfnGetOpenGLGraphicsRequirementsKHR: c.PFN_xrGetOpenGLGraphicsRequirementsKHR = undefined;
    _ = try XrResult.init(c.xrGetInstanceProcAddr(instance, "xrGetOpenGLGraphicsRequirementsKHR", &pfnGetOpenGLGraphicsRequirementsKHR));

    var graphicsRequirements: c.XrGraphicsRequirementsOpenGLKHR = .{ .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_OPENGL_KHR };
    _ = try XrResult.init((pfnGetOpenGLGraphicsRequirementsKHR.?)(instance, systemId, &graphicsRequirements));

    var major: c.GLint = 0;
    c.glGetIntegerv(c.GL_MAJOR_VERSION, &major);
    var minor: c.GLint = 0;
    c.glGetIntegerv(c.GL_MINOR_VERSION, &minor);

    const desiredApiVersion = c.XR_MAKE_VERSION(@as(i64, @intCast(major)), @as(i64, @intCast(minor)), 0);
    if (graphicsRequirements.minApiVersionSupported > desiredApiVersion) {
        @panic("Runtime does not support desired Graphics API and/or version");
    }

    // initializeResources();

    var this = @This(){
        .allocator = allocator,
    };

    var createInfo: c.XrSessionCreateInfo = .{
        .type = c.XR_TYPE_SESSION_CREATE_INFO,
        .next = graphics_binding, //gfx.GetGraphicsBinding(),
        .systemId = systemId,
    };
    _ = try XrResult.init(c.xrCreateSession(instance, &createInfo, &this.session));

    try this.logReferenceSpaces();

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## Session.deinit ##", .{});
    _ = c.xrDestroySession(this.session);
}

fn logReferenceSpaces(this: *@This()) XrError!void {
    var spaceCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(this.session, 0, &spaceCount, null));
    const spaces = try this.allocator.alloc(c.XrReferenceSpaceType, spaceCount);
    defer this.allocator.free(spaces);
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(this.session, spaceCount, &spaceCount, spaces.ptr));

    std.log.debug("Available reference spaces: {}", .{spaceCount});
    for (spaces) |space| {
        std.log.debug("  Name: {}", .{space});
    }
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
