const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;

allocator: std.mem.Allocator,
instance: xrs.Instance,
session: xrs.Session,
view_config_type: c.XrViewConfigurationType,
isSessionRunning: bool = false,

pub fn init(
    allocator: std.mem.Allocator,
    gfx_extensions: []const [*:0]const u8,
    requirements: *const fn (instance: c.XrInstance, systemId: c.XrSystemId) XrError!void,
    instance_create_info: ?*const anyopaque,
    form_factor: c.XrFormFactor,
    view_config_type: c.XrViewConfigurationType,
    gfx_binding: *const c.XrBaseInStructure,
) !@This() {
    const instance = try xrs.Instance.init(allocator, .{
        .gfx_extensions = gfx_extensions,
        .form_factor = form_factor,
        .instance_create_info = instance_create_info,
    });

    try requirements(instance.instance, instance.systemId);

    const session = try xrs.Session.init(
        allocator,
        instance.instance,
        instance.systemId,
        gfx_binding,
    );

    return .{
        .allocator = allocator,
        .instance = instance,
        .session = session,
        .view_config_type = view_config_type,
    };
}

pub fn deinit(this: *@This()) void {
    this.session.deinit();
    this.instance.deinit();
}

pub fn run_frame(this: *@This()) !enum {
    next,
    quit,
    restart,
    render,
} {
    switch (try this.instance.pollEvents()) {
        .quit => {
            return .quit;
        },
        .restart => {
            return .restart;
        },
        .next => {
            if (this.isSessionRunning) {
                return .render;
            } else {
                // Throttle loop since xrWaitFrame won't be called.
                std.Thread.sleep(std.time.ns_per_ms * 250);
            }
        },
        .session_begin => {
            try this.session.begin(this.view_config_type);
            this.isSessionRunning = true;
        },
        .session_end => {
            try this.session.end();
            this.isSessionRunning = false;
        },
    }

    return .next;
}
