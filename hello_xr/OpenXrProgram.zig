const std = @import("std");
const builtin = @import("builtin");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const xr_util = @import("xr_util");
const XrError = xr_util.XrError;
const XrResult = xr_util.XrResult;
const Options = @import("Options.zig");
const c = @import("c");
const action = @import("action.zig");
const Cube = @import("Cube.zig");
const geometry = @import("geometry.zig");

const Swapchain = struct {
    handle: c.XrSwapchain,
    width: u32,
    height: u32,
};

allocator: std.mem.Allocator,
quit_key: *const bool,
options: *Options,
instance: c.XrInstance = null,
systemId: c.XrSystemId = c.XR_NULL_SYSTEM_ID,
session: c.XrSession = null,
appSpace: c.XrSpace = null,
layer: c.XrCompositionLayerProjection = .{ .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION },

swapchains: std.ArrayList(Swapchain) = .{},
configViews: std.ArrayList(c.XrViewConfigurationView) = .{},
swapchainImages: std.AutoHashMap(c.XrSwapchain, []*c.XrSwapchainImageBaseHeader),
views: std.ArrayList(c.XrView) = .{},
colorSwapchainFormat: i64 = -1,

visualizedSpaces: std.ArrayList(c.XrSpace) = .{},

// Application's current lifecycle state according to the runtime
sessionState: c.XrSessionState = c.XR_SESSION_STATE_UNKNOWN,
sessionRunning: bool = false,

eventDataBuffer: c.XrEventDataBuffer = undefined,
projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{},

pub fn init(allocator: std.mem.Allocator, options: *Options, quit_key: *const bool) @This() {
    gfx.init(allocator);
    action.init();
    return .{
        .allocator = allocator,
        .quit_key = quit_key,
        .options = options,
        .swapchainImages = .init(allocator),
    };
}

pub fn deinit(this: *@This()) void {
    //     m_projectionLayerViews.deinit(allocator);
    action.deinit();
    gfx.deinit(this.allocator);
    {
        //         var it = m_swapchainImages.iterator();
        //         while (it.next()) |item| {
        //             allocator.free(item.value_ptr.*);
        //         }
        this.swapchainImages.deinit();
    }
    //     m_configViews.deinit(allocator);
    //
    //     //     for (Swapchain swapchain : m_swapchains) {
    //     //         xrDestroySwapchain(swapchain.handle);
    //     //     }
    //     m_swapchains.deinit(allocator);
    //
    //     m_views.deinit(allocator);
    //
    //     //     for (XrSpace visualizedSpace : m_visualizedSpaces) {
    //     //         xrDestroySpace(visualizedSpace);
    //     //     }
    //     m_visualizedSpaces.deinit(allocator);
    //
    //     //     if (m_appSpace != XR_NULL_HANDLE) {
    //     //         xrDestroySpace(m_appSpace);
    //     //     }
    //
    //     //     if (m_session != XR_NULL_HANDLE) {
    //     //         xrDestroySession(m_session);
    //     //     }
    //
    //     //     if (m_instance != XR_NULL_HANDLE) {
    //     //         xrDestroyInstance(m_instance);
    //     //     }
}

fn makeIndent(allocator: std.mem.Allocator, indent: usize) ![]const u8 {
    const str = try allocator.alloc(u8, indent);
    for (str) |*i| {
        i.* = ' ';
    }
    return str;
}

// Write out extension properties for a given layer.
fn logExtensions(allocator: std.mem.Allocator, _layerName: []const u8, indent: usize) XrError!void {
    const layerName = if (_layerName.len > 0) _layerName.ptr else null;
    var instanceExtensionCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateInstanceExtensionProperties(layerName, 0, &instanceExtensionCount, null));
    const extensions = try allocator.alloc(c.XrExtensionProperties, instanceExtensionCount);
    defer allocator.free(extensions);
    for (extensions) |*ext| {
        ext.* = .{
            .type = c.XR_TYPE_EXTENSION_PROPERTIES,
        };
    }
    _ = try XrResult.init(c.xrEnumerateInstanceExtensionProperties(layerName, @intCast(extensions.len), &instanceExtensionCount, extensions.ptr));

    const indentStr = try makeIndent(allocator, indent);
    defer allocator.free(indentStr);
    std.log.debug("{s}Available Extensions: ({})", .{ indentStr, instanceExtensionCount });
    for (extensions) |extension| {
        std.log.debug("{s}  Name={s} SpecVersion={}", .{
            indentStr,
            std.mem.sliceTo(&extension.extensionName, 0),
            extension.extensionVersion,
        });
    }
}

fn getXrVersionString(buf: []u8, ver: c.XrVersion) []const u8 {
    return std.fmt.bufPrint(buf, "{}.{}.{}", .{
        c.XR_VERSION_MAJOR(ver),
        c.XR_VERSION_MINOR(ver),
        c.XR_VERSION_PATCH(ver),
    }) catch @panic("OOM");
}

pub fn run(this: *@This(), instance_create_info: ?*anyopaque) !bool {
    // Log non-layer extensions (layerName==nullptr).
    _ = try logExtensions(this.allocator, &.{}, 0);

    // Log layers and any of their extensions.
    var version_str: [64]u8 = undefined;
    {
        var layerCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateApiLayerProperties(0, &layerCount, null));
        const layers = try this.allocator.alloc(c.XrApiLayerProperties, layerCount);
        defer this.allocator.free(layers);
        for (layers) |*l| {
            l.* = .{ .type = c.XR_TYPE_API_LAYER_PROPERTIES };
        }
        _ = try XrResult.init(c.xrEnumerateApiLayerProperties(@intCast(layers.len), &layerCount, layers.ptr));
        std.log.info("Available Layers: ({})", .{layerCount});
        for (layers) |layer| {
            std.log.debug("  Name={s} SpecVersion={s} LayerVersion={} Description={s}", .{
                layer.layerName,
                getXrVersionString(&version_str, layer.specVersion),
                layer.layerVersion,
                layer.description,
            });
            try logExtensions(this.allocator, std.mem.sliceTo(&layer.layerName, 0), 4);
        }
    }

    // Create union of extensions required by platform and graphics plugins.
    const gfx_extensions = gfx.GetInstanceExtensions();
    var extensions: std.ArrayList([*:0]const u8) = .{};
    defer extensions.deinit(this.allocator);
    for (gfx_extensions, 0..) |e, i| {
        const p: [*:0]const u8 = @ptrCast(e);
        std.log.info("GFX[{}]extension: {s}", .{ i, std.mem.span(p) });
        try extensions.append(this.allocator, e);
    }

    {
        var createInfo: c.XrInstanceCreateInfo = .{
            .type = c.XR_TYPE_INSTANCE_CREATE_INFO,
            .next = instance_create_info,
            .enabledExtensionCount = @intCast(extensions.items.len),
            .enabledExtensionNames = extensions.items.ptr,
            .applicationInfo = .{},
        };
        _ = std.fmt.bufPrintZ(&createInfo.applicationInfo.applicationName, "{s}", .{"HelloXR"}) catch @panic("OOM");
        // Current version is 1.1.x, but hello_xr only requires 1.0.x
        createInfo.applicationInfo.apiVersion = c.XR_API_VERSION_1_0;
        _ = try XrResult.init(c.xrCreateInstance(&createInfo, &this.instance));
    }

    var instanceProperties: c.XrInstanceProperties = .{ .type = c.XR_TYPE_INSTANCE_PROPERTIES };
    _ = try XrResult.init(c.xrGetInstanceProperties(this.instance, &instanceProperties));
    std.log.info("Instance RuntimeName={s} RuntimeVersion={s}", .{
        instanceProperties.runtimeName,
        getXrVersionString(&version_str, instanceProperties.runtimeVersion),
    });

    const systemInfo: c.XrSystemGetInfo = .{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = this.options.parsed.FormFactor,
    };
    _ = try XrResult.init(c.xrGetSystem(this.instance, &systemInfo, &this.systemId));
    std.log.debug("Using system {} for form factor {}", .{
        this.systemId,
        this.options.parsed.FormFactor,
    });

    try this.LogViewConfigurations();

    // The graphics API can initialize the graphics device now that the systemId and instance
    // handle are available.
    try gfx.InitializeDevice(this.instance, this.systemId);

    {
        std.log.debug("Creating session...", .{});

        var createInfo: c.XrSessionCreateInfo = .{
            .type = c.XR_TYPE_SESSION_CREATE_INFO,
            .next = gfx.GetGraphicsBinding(),
            .systemId = this.systemId,
        };
        _ = try XrResult.init(c.xrCreateSession(this.instance, &createInfo, &this.session));
    }

    try this.LogReferenceSpaces();
    try action.InitializeActions(this.instance, this.session);
    try this.CreateVisualizedSpaces();

    {
        const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(this.options.AppSpace.span());
        _ = try XrResult.init(c.xrCreateReferenceSpace(this.session, &referenceSpaceCreateInfo, &this.appSpace));
    }

    try this.CreateSwapchains();

    while (!this.quit_key.*) {
        switch (try this.run_frame()) {
            .next => {},
            .quit => {
                return false;
            },
            .restart => {
                return true;
            },
        }
    }

    return false;
}

fn run_frame(this: *@This()) !NextFrame {
    const next = try this.PollEvents();
    switch (next) {
        .quit => {
            return .quit;
        },
        .restart => {
            return .restart;
        },
        .render => {},
    }

    if (this.IsSessionRunning()) {
        try action.PollActions(this.session);
        // try OpenXrProgram.oRenderFrame(allocator);
        const frameState = try this.beginFrame();
        var layer: ?*c.XrCompositionLayerBaseHeader = null;
        if (frameState.shouldRender == c.XR_TRUE) {
            if (try this.locate(frameState.predictedDisplayTime)) {
                layer = try this.RenderLayer(
                    frameState.predictedDisplayTime,
                );
            }
        }
        try this.endFrame(frameState.predictedDisplayTime, layer);
    } else {
        // Throttle loop since xrWaitFrame won't be called.
        std.Thread.sleep(std.time.ns_per_ms * 250);
    }
    return .next;
}

fn LogEnvironmentBlendMode(this: *@This(), _type: c.XrViewConfigurationType) XrError!void {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(this.instance, this.systemId, _type, 0, &count, null));
    std.debug.assert(count > 0);

    std.log.info("Available Environment Blend Mode count : ({})", .{count});

    const blendModes = try this.allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer this.allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(this.instance, this.systemId, _type, count, &count, blendModes.ptr));

    var blendModeFound = false;
    for (blendModes) |mode| {
        const blendModeMatch = (mode == this.GetPreferredBlendMode() catch @panic("OOM"));
        std.log.info("Environment Blend Mode ({}) : {s}", .{ mode, if (blendModeMatch) "(Selected)" else "" });
        blendModeFound |= blendModeMatch;
    }
    std.debug.assert(blendModeFound);
}

pub fn GetPreferredBlendMode(this: *@This()) !c.XrEnvironmentBlendMode {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        this.options.parsed.ViewConfigType,
        0,
        &count,
        null,
    ));
    const blendModes = try this.allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer this.allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        this.instance,
        this.systemId,
        this.options.parsed.ViewConfigType,
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

fn LogViewConfigurations(this: *@This()) XrError!void {
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

    std.log.info("Available View Configuration Types: ({})", .{viewConfigTypeCount});
    for (viewConfigTypes) |viewConfigType| {
        std.log.debug("  View Configuration Type: {} {s}", .{
            viewConfigType,
            if (viewConfigType == this.options.parsed.ViewConfigType) "(Selected)" else "",
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

        try this.LogEnvironmentBlendMode(viewConfigType);
    }
}

fn LogReferenceSpaces(this: *@This()) XrError!void {
    std.debug.assert(this.session != null);

    var spaceCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(this.session, 0, &spaceCount, null));
    const spaces = try this.allocator.alloc(c.XrReferenceSpaceType, spaceCount);
    defer this.allocator.free(spaces);
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(this.session, spaceCount, &spaceCount, spaces.ptr));

    std.log.info("Available reference spaces: {}", .{spaceCount});
    for (spaces) |space| {
        std.log.debug("  Name: {}", .{space});
    }
}

fn CreateVisualizedSpaces(this: *@This()) !void {
    const visualizedSpaces = [_][]const u8{
        "ViewFront", "Local", "Stage", "StageLeft", "StageRight", "StageLeftRotated", "StageRightRotated",
    };

    for (visualizedSpaces) |visualizedSpace| {
        const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(visualizedSpace);
        var space: c.XrSpace = undefined;
        const res = c.xrCreateReferenceSpace(this.session, &referenceSpaceCreateInfo, &space);
        if (c.XR_SUCCEEDED(res)) {
            try this.visualizedSpaces.append(this.allocator, space);
        } else {
            std.log.warn("Failed to create reference space {s} with error {}", .{ visualizedSpace, res });
        }
    }
}

pub fn CreateSwapchains(this: *@This()) XrError!void {
    // Read graphics properties for preferred swapchain length and logging.
    var systemProperties: c.XrSystemProperties = .{ .type = c.XR_TYPE_SYSTEM_PROPERTIES };
    _ = try XrResult.init(c.xrGetSystemProperties(this.instance, this.systemId, &systemProperties));

    // Log system properties.
    std.log.info("System Properties: Name={s} VendorId={}", .{
        systemProperties.systemName,
        systemProperties.vendorId,
    });
    std.log.info("System Graphics Properties: MaxWidth={} MaxHeight={} MaxLayers={}", .{
        systemProperties.graphicsProperties.maxSwapchainImageWidth,
        systemProperties.graphicsProperties.maxSwapchainImageHeight,
        systemProperties.graphicsProperties.maxLayerCount,
    });
    std.log.info("System Tracking Properties: OrientationTracking={s} PositionTracking={s}", .{
        if (systemProperties.trackingProperties.orientationTracking == c.XR_TRUE) "True" else "False",
        if (systemProperties.trackingProperties.positionTracking == c.XR_TRUE) "True" else "False",
    });
    // Note: No other view configurations exist at the time this code was written. If this
    // condition is not met, the project will need to be audited to see how support should be
    // added.
    std.debug.assert(this.options.parsed.ViewConfigType == c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO); //, "Unsupported view configuration type");

    // Query and cache view configuration views.
    var viewCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(this.instance, this.systemId, this.options.parsed.ViewConfigType, 0, &viewCount, null));
    try this.configViews.resize(this.allocator, viewCount);
    for (this.configViews.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
    }
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
        this.instance,
        this.systemId,
        this.options.parsed.ViewConfigType,
        viewCount,
        &viewCount,
        this.configViews.items.ptr,
    ));

    // Create and cache view buffer for xrLocateViews later.
    try this.views.resize(this.allocator, viewCount);
    for (this.views.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW };
    }

    // Create the swapchain and get the images.
    if (viewCount > 0) {
        // Select a swapchain format.
        var swapchainFormatCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateSwapchainFormats(this.session, 0, &swapchainFormatCount, null));
        const swapchainFormats = try this.allocator.alloc(i64, swapchainFormatCount);
        defer this.allocator.free(swapchainFormats);
        _ = try XrResult.init(c.xrEnumerateSwapchainFormats(
            this.session,
            @intCast(swapchainFormats.len),
            &swapchainFormatCount,
            swapchainFormats.ptr,
        ));
        std.debug.assert(swapchainFormatCount == swapchainFormats.len);
        this.colorSwapchainFormat = try gfx.SelectColorSwapchainFormat(this.allocator, swapchainFormats);

        // Print swapchain formats and the selected one.
        {
            // const swapchainFormatsString: []const u8 = "";
            var out = std.Io.Writer.Allocating.init(this.allocator);
            defer out.deinit();
            // std.io.Writer を値渡しすると壊れる
            var w: *std.io.Writer = &out.writer;

            for (swapchainFormats) |format| {
                const selected = format == this.colorSwapchainFormat;
                w.writeAll(" ") catch @panic("OOM");
                if (selected) {
                    w.writeAll("[") catch @panic("OOM");
                }
                w.print("{}", .{format}) catch @panic("OM");
                if (selected) {
                    w.writeAll("]") catch @panic("OOM");
                }
            }
            const str = out.toOwnedSlice() catch @panic("OOM");
            defer this.allocator.free(str);
            std.log.debug("Swapchain Formats: {s}", .{str});
        }

        // Create a swapchain for each view.
        for (this.configViews.items, 0..) |vp, i| {
            std.log.info("Creating swapchain for view {} with dimensions Width={} Height={} SampleCount={}", .{
                i,
                vp.recommendedImageRectWidth,
                vp.recommendedImageRectHeight,
                vp.recommendedSwapchainSampleCount,
            });

            // Create the swapchain.
            var swapchainCreateInfo: c.XrSwapchainCreateInfo = .{
                .type = c.XR_TYPE_SWAPCHAIN_CREATE_INFO,
                .arraySize = 1,
                .format = this.colorSwapchainFormat,
                .width = vp.recommendedImageRectWidth,
                .height = vp.recommendedImageRectHeight,
                .mipCount = 1,
                .faceCount = 1,
                .sampleCount = gfx.GetSupportedSwapchainSampleCount(&vp),
                .usageFlags = c.XR_SWAPCHAIN_USAGE_SAMPLED_BIT | c.XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT,
            };

            var swapchain: Swapchain = .{
                .handle = null,
                .width = swapchainCreateInfo.width,
                .height = swapchainCreateInfo.height,
            };
            _ = try XrResult.init(c.xrCreateSwapchain(this.session, &swapchainCreateInfo, &swapchain.handle));

            try this.swapchains.append(this.allocator, swapchain);

            var imageCount: u32 = undefined;
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, 0, &imageCount, null));
            // XXX This should really just return XrSwapchainImageBaseHeader*
            const swapchainImages = try this.allocator.alloc(*c.XrSwapchainImageBaseHeader, imageCount);
            try gfx.AllocateSwapchainImageStructs(this.allocator, swapchainImages);
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, imageCount, &imageCount, swapchainImages[0]));

            try this.swapchainImages.put(swapchain.handle, swapchainImages);
        }
    }
}

// Return event if one is available, otherwise return null.
pub fn TryReadNextEvent(this: *@This()) ?*c.XrEventDataBaseHeader {
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

pub const SessionNext = enum {
    next,
    quit,
    restart,
};

fn HandleSessionStateChangedEvent(
    this: *@This(),
    stateChangedEvent: *c.XrEventDataSessionStateChanged,
    // exitRenderLoop: *bool,
    // requestRestart: *bool,
) XrError!SessionNext {
    const oldState = this.sessionState;
    this.sessionState = stateChangedEvent.state;

    std.log.info("XrEventDataSessionStateChanged: state {}->{} session={?} time={}", .{
        oldState,
        this.sessionState,
        stateChangedEvent.session,
        stateChangedEvent.time,
    });

    if ((stateChangedEvent.session != null) and (stateChangedEvent.session != this.session)) {
        std.log.err("XrEventDataSessionStateChanged for unknown session", .{});
        return .next;
    }

    switch (this.sessionState) {
        c.XR_SESSION_STATE_READY => {
            std.debug.assert(this.session != null);
            var sessionBeginInfo: c.XrSessionBeginInfo = .{
                .type = c.XR_TYPE_SESSION_BEGIN_INFO,
            };
            sessionBeginInfo.primaryViewConfigurationType = this.options.parsed.ViewConfigType;
            _ = try XrResult.init(c.xrBeginSession(this.session, &sessionBeginInfo));
            this.sessionRunning = true;
            return .next;
        },
        c.XR_SESSION_STATE_STOPPING => {
            std.debug.assert(this.session != null);
            this.sessionRunning = false;
            _ = try XrResult.init(c.xrEndSession(this.session));
            return .next;
        },
        c.XR_SESSION_STATE_EXITING => {
            return .quit;
        },
        c.XR_SESSION_STATE_LOSS_PENDING => {
            return .restart;
        },
        else => {
            return .next;
        },
    }
}

pub const EventNext = enum {
    render,
    quit,
    restart,
};

pub fn PollEvents(
    this: *@This(),
) !EventNext {
    // Process all pending messages.
    while (this.TryReadNextEvent()) |event| {
        switch (event.type) {
            c.XR_TYPE_EVENT_DATA_INSTANCE_LOSS_PENDING => {
                // https://registry.khronos.org/OpenXR/specs/1.0/man/html/XrEventDataInstanceLossPending.html
                const instanceLossPending: *c.XrEventDataInstanceLossPending = @ptrCast(event);
                std.log.warn("XrEventDataInstanceLossPending by {}", .{instanceLossPending.lossTime});
                return .restart;
            },
            c.XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED => {
                const sessionStateChangedEvent: *c.XrEventDataSessionStateChanged = @ptrCast(event);
                switch (try this.HandleSessionStateChangedEvent(sessionStateChangedEvent)) {
                    .next => {},
                    .quit => {
                        return .quit;
                    },
                    .restart => {
                        return .restart;
                    },
                }
            },
            c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => {
                try action.LogEvent(this.allocator, this.session);
            },
            // case XR_TYPE_EVENT_DATA_REFERENCE_SPACE_CHANGE_PENDING:
            else => {
                std.log.debug("Ignoring event type {}", .{event.type});
            },
        }
    }
    return .render;
}

pub fn IsSessionRunning(this: *@This()) bool {
    return this.sessionRunning;
}

pub fn IsSessionFocused(this: *@This()) bool {
    return this.m_sessionState == c.XR_SESSION_STATE_FOCUSED;
}

pub fn RenderLayer(
    this: *@This(),
    predictedDisplayTime: c.XrTime,
) !*c.XrCompositionLayerBaseHeader {
    // std.debug.assert(viewCountOutput == viewCapacityInput);
    // std.debug.assert(viewCountOutput == m_configViews.items.len);
    // std.debug.assert(viewCountOutput == m_swapchains.items.len);

    try this.projectionLayerViews.resize(this.allocator, this.views.items.len);

    // For each locatable space that we want to visualize, render a 25cm cube.
    var cubes: std.ArrayList(Cube) = .{};
    defer cubes.deinit(this.allocator);
    for (this.visualizedSpaces.items) |visualizedSpace| {
        var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
        const res = try XrResult.init(c.xrLocateSpace(visualizedSpace, this.appSpace, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                try cubes.append(this.allocator, .init(spaceLocation.pose, .{ .x = 0.25, .y = 0.25, .z = 0.25 }));
            }
        } else {
            std.log.debug("Unable to locate a visualized reference space in app space: {}", .{res});
        }
    }

    // Render a 10cm cube scaled by grabAction for each hand. Note renderHand will only be
    // true when the application has focus.
    const hands = [2]usize{ action.Side.LEFT, action.Side.RIGHT };
    for (hands) |hand| {
        var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
        const res = try XrResult.init(c.xrLocateSpace(action.m_input.handSpace[hand], this.appSpace, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                const scale = 0.1 * action.m_input.handScale[hand];
                try cubes.append(this.allocator, .init(spaceLocation.pose, .{ .x = scale, .y = scale, .z = scale }));
            }
        } else {
            // Tracking loss is expected when the hand is not active so only log a message
            // if the hand is active.
            if (action.m_input.handActive[hand] == c.XR_TRUE) {
                const handName = [2][]const u8{ "left", "right" };
                std.log.debug("Unable to locate {s} hand action space in app space: {}", .{ handName[hand], res });
            }
        }
    }

    // Render view to the appropriate part of the swapchain image.
    for (this.swapchains.items, 0..) |viewSwapchain, i| {
        // Each view has a separate swapchain which is acquired, rendered to, and released.
        var acquireInfo: c.XrSwapchainImageAcquireInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO };
        var swapchainImageIndex: u32 = undefined;
        _ = try XrResult.init(c.xrAcquireSwapchainImage(viewSwapchain.handle, &acquireInfo, &swapchainImageIndex));

        var waitInfo: c.XrSwapchainImageWaitInfo = .{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO,
            .timeout = c.XR_INFINITE_DURATION,
        };
        _ = try XrResult.init(c.xrWaitSwapchainImage(viewSwapchain.handle, &waitInfo));

        this.projectionLayerViews.items[i] = .{
            .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW,
            .pose = this.views.items[i].pose,
            .fov = this.views.items[i].fov,
            .subImage = .{
                .swapchain = viewSwapchain.handle,
                .imageRect = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = @intCast(viewSwapchain.width), .height = @intCast(viewSwapchain.height) },
                },
            },
        };

        const entry = this.swapchainImages.get(viewSwapchain.handle).?;
        const swapchainImage: *c.XrSwapchainImageBaseHeader = entry[swapchainImageIndex];
        try gfx.RenderView(
            &this.projectionLayerViews.items[i],
            swapchainImage,
            this.colorSwapchainFormat,
            Options.GetBackgroundClearColor(try this.GetPreferredBlendMode()),
            cubes.items,
        );

        var releaseInfo: c.XrSwapchainImageReleaseInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO };
        _ = try XrResult.init(c.xrReleaseSwapchainImage(viewSwapchain.handle, &releaseInfo));
    }

    this.layer = .{
        .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
        .space = this.appSpace,
        .layerFlags = if (try this.GetPreferredBlendMode() == c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND)
            c.XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT | c.XR_COMPOSITION_LAYER_UNPREMULTIPLIED_ALPHA_BIT
        else
            0,
        .viewCount = @intCast(this.projectionLayerViews.items.len),
        .views = this.projectionLayerViews.items.ptr,
    };
    return @ptrCast(&this.layer);
}

pub fn endFrame(this: *@This(), predictedDisplayTime: c.XrTime, maybe_layer: ?*c.XrCompositionLayerBaseHeader) !void {
    var frameEndInfo: c.XrFrameEndInfo = .{
        .type = c.XR_TYPE_FRAME_END_INFO,
        .displayTime = predictedDisplayTime,
        .environmentBlendMode = try this.GetPreferredBlendMode(),
        .layerCount = if (maybe_layer != null) 1 else 0,
        .layers = if (maybe_layer) |layer| &layer else null,
    };
    _ = try XrResult.init(c.xrEndFrame(this.session, &frameEndInfo));
}

pub fn beginFrame(this: @This()) !c.XrFrameState {
    var frameWaitInfo: c.XrFrameWaitInfo = .{ .type = c.XR_TYPE_FRAME_WAIT_INFO };
    var frameState: c.XrFrameState = .{ .type = c.XR_TYPE_FRAME_STATE };
    _ = try XrResult.init(c.xrWaitFrame(this.session, &frameWaitInfo, &frameState));

    var frameBeginInfo: c.XrFrameBeginInfo = .{ .type = c.XR_TYPE_FRAME_BEGIN_INFO };
    _ = try XrResult.init(c.xrBeginFrame(this.session, &frameBeginInfo));

    return frameState;
}

pub fn locate(this: *@This(), predictedDisplayTime: c.XrTime) !bool {
    var viewState: c.XrViewState = .{ .type = c.XR_TYPE_VIEW_STATE };
    const viewCapacityInput: u32 = @intCast(this.views.items.len);
    var viewCountOutput: u32 = undefined;
    var viewLocateInfo: c.XrViewLocateInfo = .{
        .type = c.XR_TYPE_VIEW_LOCATE_INFO,
        .viewConfigurationType = this.options.parsed.ViewConfigType,
        .displayTime = predictedDisplayTime,
        .space = this.appSpace,
    };

    _ = try XrResult.init(c.xrLocateViews(
        this.session,
        &viewLocateInfo,
        &viewState,
        viewCapacityInput,
        &viewCountOutput,
        this.views.items.ptr,
    ));
    if ((viewState.viewStateFlags & c.XR_VIEW_STATE_POSITION_VALID_BIT) == 0 or
        (viewState.viewStateFlags & c.XR_VIEW_STATE_ORIENTATION_VALID_BIT) == 0)
    {
        return false; // There is no valid tracking poses for the views.
    } else {
        return true;
    }
}

const NextFrame = enum {
    next,
    quit,
    restart,
};
