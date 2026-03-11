const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrResult = xr_result.XrResult;
const XrError = xr_result.XrError;
const xr_util = @import("xr_util.zig");

allocator: std.mem.Allocator,
instance: c.XrInstance = null,
systemId: c.XrSystemId = c.XR_NULL_SYSTEM_ID,
eventDataBuffer: c.XrEventDataBuffer = undefined,
sessionState: c.XrSessionState = c.XR_SESSION_STATE_UNKNOWN,

var version_str: [64]u8 = undefined;

pub const Options = struct {
    instance_create_info: ?*anyopaque = null,
    gfx_extensions: []const [*:0]const u8,
    form_factor: c.XrFormFactor,
};

pub fn init(allocator: std.mem.Allocator, opts: Options) XrError!@This() {
    std.log.info("## Instance.init ##", .{});
    // Log non-layer extensions (layerName==nullptr).
    // _ = try logExtensions(this.allocator, &.{}, 0);

    // Log layers and any of their extensions.
    // {
    //     var layerCount: u32 = undefined;
    //     _ = try XrResult.init(c.xrEnumerateApiLayerProperties(0, &layerCount, null));
    //     const layers = try this.allocator.alloc(c.XrApiLayerProperties, layerCount);
    //     defer this.allocator.free(layers);
    //     for (layers) |*l| {
    //         l.* = .{ .type = c.XR_TYPE_API_LAYER_PROPERTIES };
    //     }
    //     _ = try XrResult.init(c.xrEnumerateApiLayerProperties(@intCast(layers.len), &layerCount, layers.ptr));
    //     std.log.info("Available Layers: ({})", .{layerCount});
    //     for (layers) |layer| {
    //         std.log.debug("  Name={s} SpecVersion={s} LayerVersion={} Description={s}", .{
    //             layer.layerName,
    //             getXrVersionString(&version_str, layer.specVersion),
    //             layer.layerVersion,
    //             layer.description,
    //         });
    //         try logExtensions(this.allocator, std.mem.sliceTo(&layer.layerName, 0), 4);
    //     }
    // }

    var this = @This(){
        .allocator = allocator,
    };

    // Create union of extensions required by platform and graphics plugins.
    // const gfx_extensions = gfx.GetInstanceExtensions();
    var extensions: std.ArrayList([*:0]const u8) = .{};
    defer extensions.deinit(allocator);
    for (opts.gfx_extensions, 0..) |e, i| {
        const p: [*:0]const u8 = @ptrCast(e);
        std.log.debug("GFX[{}]extension: {s}", .{ i, std.mem.span(p) });
        try extensions.append(allocator, e);
    }
    var createInfo: c.XrInstanceCreateInfo = .{
        .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
        .next = opts.instance_create_info,
        .enabledExtensionCount = @intCast(extensions.items.len),
        .enabledExtensionNames = extensions.items.ptr,
        .applicationInfo = .{},
    };
    _ = std.fmt.bufPrintZ(&createInfo.applicationInfo.applicationName, "{s}", .{"HelloXR"}) catch @panic("OOM");
    // Current version is 1.1.x, but hello_xr only requires 1.0.x
    createInfo.applicationInfo.apiVersion = c.XR_API_VERSION_1_0;
    _ = try XrResult.init(c.xrCreateInstance(&createInfo, &this.instance));

    var instanceProperties: c.XrInstanceProperties = .{ .type = c.XR_TYPE_INSTANCE_PROPERTIES };
    _ = try XrResult.init(c.xrGetInstanceProperties(this.instance, &instanceProperties));
    std.log.debug("Instance RuntimeName={s} RuntimeVersion={s}", .{
        instanceProperties.runtimeName,
        xr_util.getXrVersionString(&version_str, instanceProperties.runtimeVersion),
    });

    const systemInfo: c.XrSystemGetInfo = .{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = opts.form_factor,
    };
    _ = try XrResult.init(c.xrGetSystem(this.instance, &systemInfo, &this.systemId));
    std.log.debug("Using system {} for form factor {}", .{
        this.systemId,
        systemInfo.formFactor,
    });

    // Read graphics properties for preferred swapchain length and logging.
    var systemProperties: c.XrSystemProperties = .{ .type = c.XR_TYPE_SYSTEM_PROPERTIES };
    _ = try XrResult.init(c.xrGetSystemProperties(this.instance, this.systemId, &systemProperties));

    // Log system properties.
    std.log.debug("System Properties: Name={s} VendorId={}", .{
        systemProperties.systemName,
        systemProperties.vendorId,
    });
    std.log.debug("System Graphics Properties: MaxWidth={} MaxHeight={} MaxLayers={}", .{
        systemProperties.graphicsProperties.maxSwapchainImageWidth,
        systemProperties.graphicsProperties.maxSwapchainImageHeight,
        systemProperties.graphicsProperties.maxLayerCount,
    });
    std.log.debug("System Tracking Properties: OrientationTracking={s} PositionTracking={s}", .{
        if (systemProperties.trackingProperties.orientationTracking == c.XR_TRUE) "True" else "False",
        if (systemProperties.trackingProperties.positionTracking == c.XR_TRUE) "True" else "False",
    });

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## Instance.deinit ##", .{});
    if (this.instance) |handle| {
        _ = c.xrDestroyInstance(handle);
    }
}

pub fn logViewConfigurations(
    this: *@This(),
    view_config_type: c.XrViewConfigurationType,
    blend_mode: c.XrEnvironmentBlendMode,
) XrError!void {
    var viewConfigTypeCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(
        this.instance,
        this.systemId,
        0,
        &viewConfigTypeCount,
        null,
    ));
    const viewConfigTypes = try this.allocator.alloc(c.XrViewConfigurationType, viewConfigTypeCount);
    defer this.allocator.free(viewConfigTypes);
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(
        this.instance,
        this.systemId,
        viewConfigTypeCount,
        &viewConfigTypeCount,
        viewConfigTypes.ptr,
    ));
    std.debug.assert(viewConfigTypes.len == viewConfigTypeCount);

    std.log.debug("Available View Configuration Types: ({})", .{viewConfigTypeCount});
    for (viewConfigTypes) |viewConfigType| {
        std.log.debug("  View Configuration Type: {} {s}", .{
            viewConfigType,
            if (viewConfigType == view_config_type) "(Selected)" else "",
        });

        var viewConfigProperties: c.XrViewConfigurationProperties = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_PROPERTIES };
        _ = try XrResult.init(c.xrGetViewConfigurationProperties(
            this.instance,
            this.systemId,
            viewConfigType,
            &viewConfigProperties,
        ));

        std.log.debug("  View configuration FovMutable={s}", .{
            if (viewConfigProperties.fovMutable == c.XR_TRUE) "True" else "False",
        });

        var viewCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
            this.instance,
            this.systemId,
            viewConfigType,
            0,
            &viewCount,
            null,
        ));
        if (viewCount > 0) {
            const views = try this.allocator.alloc(c.XrViewConfigurationView, viewCount);
            defer this.allocator.free(views);
            for (views) |*view| {
                view.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
            }
            _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
                this.instance,
                this.systemId,
                viewConfigType,
                viewCount,
                &viewCount,
                views.ptr,
            ));

            for (views, 0..) |view, i| {
                std.log.debug("    View [{}]: Recommended Width={} Height={} SampleCount={}", .{
                    i,                               view.recommendedImageRectWidth,
                    view.recommendedImageRectHeight, view.recommendedSwapchainSampleCount,
                });
                std.log.debug("    View [{}]:     Maximum Width={} Height={} SampleCount={}", .{
                    i,
                    view.maxImageRectWidth,
                    view.maxImageRectHeight,
                    view.maxSwapchainSampleCount,
                });
            }
        } else {
            std.log.err("Empty view configuration type", .{});
        }

        try this.logEnvironmentBlendMode(viewConfigType, blend_mode);
    }
}

fn logEnvironmentBlendMode(
    this: *@This(),
    view_config_type: c.XrViewConfigurationType,
    blend_mode: c.XrEnvironmentBlendMode,
) XrError!void {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        view_config_type,
        0,
        &count,
        null,
    ));
    std.debug.assert(count > 0);

    std.log.debug("Available Environment Blend Mode count : ({})", .{count});

    const blendModes = try this.allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer this.allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        view_config_type,
        count,
        &count,
        blendModes.ptr,
    ));

    var blendModeFound = false;
    for (blendModes) |mode| {
        const blendModeMatch = (mode == blend_mode);
        std.log.debug("Environment Blend Mode ({}) : {s}", .{ mode, if (blendModeMatch) "(Selected)" else "" });
        blendModeFound |= blendModeMatch;
    }
    std.debug.assert(blendModeFound);
}

pub fn getPreferredBlendMode(this: *@This(), view_config_type: c.XrViewConfigurationType) !c.XrEnvironmentBlendMode {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        view_config_type,
        0,
        &count,
        null,
    ));
    const blendModes = try this.allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer this.allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        view_config_type,
        count,
        &count,
        blendModes.ptr,
    ));
    const acceptableBlendModes = [_]c.XrEnvironmentBlendMode{
        c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
        c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE,
        c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND,
    };
    for (blendModes) |blendMode| {
        for (acceptableBlendModes) |mode| {
            if (blendMode == mode) {
                return blendMode;
            }
        }
    }
    // THROW("No acceptable blend mode returned from the xrEnumerateEnvironmentBlendModes");
    return error.NoAcceptableBlendMode;
}
pub fn IsSessionFocused(this: *@This()) bool {
    return this.m_sessionState == c.XR_SESSION_STATE_FOCUSED;
}

pub const EventNext = enum {
    next,
    quit,
    restart,
    session_begin,
    session_end,
};

pub fn pollEvents(
    this: *@This(),
    // view_config_type: c.XrViewConfigurationType,
    // session: c.XrSession,
) !EventNext {
    // Process all pending messages.
    while (this.tryReadNextEvent()) |event| {
        switch (event.type) {
            c.XR_TYPE_EVENT_DATA_INSTANCE_LOSS_PENDING => {
                // https://registry.khronos.org/OpenXR/specs/1.0/man/html/XrEventDataInstanceLossPending.html
                const instanceLossPending: *c.XrEventDataInstanceLossPending = @ptrCast(event);
                std.log.warn("XrEventDataInstanceLossPending by {}", .{instanceLossPending.lossTime});
                return .restart;
            },
            c.XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED => {
                const stateChangedEvent: *c.XrEventDataSessionStateChanged = @ptrCast(event);
                const oldState = this.sessionState;
                this.sessionState = stateChangedEvent.state;
                std.log.debug("XrEventDataSessionStateChanged: state {}->{} session={?} time={}", .{
                    oldState,
                    this.sessionState,
                    stateChangedEvent.session,
                    stateChangedEvent.time,
                });

                // if ((stateChangedEvent.session != null) and (stateChangedEvent.session != session)) {
                //     std.log.err("XrEventDataSessionStateChanged for unknown session", .{});
                //     return .next;
                // }

                switch (this.sessionState) {
                    c.XR_SESSION_STATE_READY => {
                        return .session_begin;
                    },
                    c.XR_SESSION_STATE_STOPPING => {
                        return .session_end;
                    },
                    c.XR_SESSION_STATE_EXITING => {
                        return .quit;
                    },
                    c.XR_SESSION_STATE_LOSS_PENDING => {
                        return .restart;
                    },
                    else => {},
                }
            },
            c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => {
                // try action.LogEvent(this.allocator, this.session);
            },
            // case XR_TYPE_EVENT_DATA_REFERENCE_SPACE_CHANGE_PENDING:
            else => {
                std.log.debug("Ignoring event type {}", .{event.type});
            },
        }
    }
    return .next;
}

// Return event if one is available, otherwise return null.
fn tryReadNextEvent(this: *@This()) ?*c.XrEventDataBaseHeader {
    // It is sufficient to clear the just the XrEventDataBuffer header to
    // XR_TYPE_EVENT_DATA_BUFFER
    const baseHeader: *c.XrEventDataBaseHeader = @ptrCast(&this.eventDataBuffer);
    baseHeader.* = .{ .type = c.XR_TYPE_EVENT_DATA_BUFFER };
    const xr = c.xrPollEvent(this.instance, &this.eventDataBuffer);
    if (xr == c.XR_SUCCESS) {
        if (baseHeader.type == c.XR_TYPE_EVENT_DATA_EVENTS_LOST) {
            const eventsLost: *c.XrEventDataEventsLost = @ptrCast(baseHeader);
            std.log.warn("{} events lost", .{eventsLost.lostEventCount});
        }
        return baseHeader;
    }
    if (xr == c.XR_EVENT_UNAVAILABLE) {
        return null;
    }
    @panic("xrPollEvent");
}
