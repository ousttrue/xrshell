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
const Cube = @import("Cube.zig");
const geometry = @import("geometry.zig");
const action = @import("action.zig");

var version_str: [64]u8 = undefined;
fn GetXrVersionString(ver: c.XrVersion) []const u8 {
    return std.fmt.bufPrint(&version_str, "{}.{}.{}", .{
        c.XR_VERSION_MAJOR(ver),
        c.XR_VERSION_MINOR(ver),
        c.XR_VERSION_PATCH(ver),
    }) catch @panic("OOM");
}

var m_options: *Options = undefined;
var m_instance: c.XrInstance = null;
var m_session: c.XrSession = null;
var m_appSpace: c.XrSpace = null;
var m_systemId: c.XrSystemId = c.XR_NULL_SYSTEM_ID;

const Swapchain = struct {
    handle: c.XrSwapchain,
    width: u32,
    height: u32,
};

var m_configViews: std.ArrayList(c.XrViewConfigurationView) = .{};
var m_swapchains: std.ArrayList(Swapchain) = .{};
var m_swapchainImages: std.AutoHashMap(c.XrSwapchain, []*c.XrSwapchainImageBaseHeader) = undefined;
var m_views: std.ArrayList(c.XrView) = .{};
var m_colorSwapchainFormat: i64 = -1;

var m_visualizedSpaces: std.ArrayList(c.XrSpace) = .{};

// Application's current lifecycle state according to the runtime
var m_sessionState: c.XrSessionState = c.XR_SESSION_STATE_UNKNOWN;
var m_sessionRunning: bool = false;

var m_eventDataBuffer: c.XrEventDataBuffer = undefined;

pub fn init(allocator: std.mem.Allocator, options: *Options) void {
    m_options = options;
    m_swapchainImages = .init(allocator);
    gfx.init(allocator, options);
    // platformplugin.UpdateOptions(options);
    // graphicsplugin.UpdateOptions(options);
    action.init();
}

pub fn deinit(allocator: std.mem.Allocator) void {
    action.deinit();

    gfx.deinit(allocator);
    {
        var it = m_swapchainImages.iterator();
        while (it.next()) |item| {
            allocator.free(item.value_ptr.*);
        }
        m_swapchainImages.deinit();
    }
    m_configViews.deinit(allocator);

    //     for (Swapchain swapchain : m_swapchains) {
    //         xrDestroySwapchain(swapchain.handle);
    //     }
    m_swapchains.deinit(allocator);

    m_views.deinit(allocator);

    //     for (XrSpace visualizedSpace : m_visualizedSpaces) {
    //         xrDestroySpace(visualizedSpace);
    //     }
    m_visualizedSpaces.deinit(allocator);

    //     if (m_appSpace != XR_NULL_HANDLE) {
    //         xrDestroySpace(m_appSpace);
    //     }

    //     if (m_session != XR_NULL_HANDLE) {
    //         xrDestroySession(m_session);
    //     }

    //     if (m_instance != XR_NULL_HANDLE) {
    //         xrDestroyInstance(m_instance);
    //     }
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

fn LogLayersAndExtensions(allocator: std.mem.Allocator) XrError!void {

    // Log non-layer extensions (layerName==nullptr).
    _ = try logExtensions(allocator, &.{}, 0);

    // Log layers and any of their extensions.
    {
        var layerCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateApiLayerProperties(0, &layerCount, null));
        const layers = try allocator.alloc(c.XrApiLayerProperties, layerCount);
        defer allocator.free(layers);
        for (layers) |*l| {
            l.* = .{ .type = c.XR_TYPE_API_LAYER_PROPERTIES };
        }
        _ = try XrResult.init(c.xrEnumerateApiLayerProperties(@intCast(layers.len), &layerCount, layers.ptr));
        std.log.info("Available Layers: ({})", .{layerCount});
        for (layers) |layer| {
            std.log.debug("  Name={s} SpecVersion={s} LayerVersion={} Description={s}", .{
                layer.layerName,
                GetXrVersionString(layer.specVersion),
                layer.layerVersion,
                layer.description,
            });
            try logExtensions(allocator, std.mem.sliceTo(&layer.layerName, 0), 4);
        }
    }
}

fn CreateInstanceInternal(allocator: std.mem.Allocator, instance_create_info: ?*const anyopaque) XrError!void {
    std.debug.assert(m_instance == null);

    const gfx_extensions = gfx.GetInstanceExtensions();

    // Create union of extensions required by platform and graphics plugins.
    var extensions: std.ArrayList([*:0]const u8) = .{};
    defer extensions.deinit(allocator);
    for (gfx_extensions, 0..) |e, i| {
        const p: [*:0]const u8 = @ptrCast(e);
        std.log.info("GFX[{}]extension: {s}", .{ i, std.mem.span(p) });
        try extensions.append(allocator, e);
    }

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

    _ = try XrResult.init(c.xrCreateInstance(&createInfo, &m_instance));
}

fn LogInstanceInfo() XrError!void {
    std.debug.assert(m_instance != null);

    var instanceProperties: c.XrInstanceProperties = .{ .type = c.XR_TYPE_INSTANCE_PROPERTIES };
    _ = try XrResult.init(c.xrGetInstanceProperties(m_instance, &instanceProperties));

    std.log.info("Instance RuntimeName={s} RuntimeVersion={s}", .{
        instanceProperties.runtimeName,
        GetXrVersionString(instanceProperties.runtimeVersion),
    });
}

pub fn CreateInstance(allocator: std.mem.Allocator, instance_create_info: ?*const anyopaque) !void {
    try LogLayersAndExtensions(allocator);
    try CreateInstanceInternal(allocator, instance_create_info);
    try LogInstanceInfo();
}

fn LogEnvironmentBlendMode(allocator: std.mem.Allocator, _type: c.XrViewConfigurationType) XrError!void {
    std.debug.assert(m_instance != null);
    std.debug.assert(m_systemId != 0);

    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(m_instance, m_systemId, _type, 0, &count, null));
    std.debug.assert(count > 0);

    std.log.info("Available Environment Blend Mode count : ({})", .{count});

    const blendModes = try allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(m_instance, m_systemId, _type, count, &count, blendModes.ptr));

    var blendModeFound = false;
    for (blendModes) |mode| {
        const blendModeMatch = (mode == m_options.parsed.EnvironmentBlendMode);
        std.log.info("Environment Blend Mode ({}) : {s}", .{ mode, if (blendModeMatch) "(Selected)" else "" });
        blendModeFound |= blendModeMatch;
    }
    std.debug.assert(blendModeFound);
}

const m_acceptableBlendModes = [_]c.XrEnvironmentBlendMode{
    c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
    c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE,
    c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND,
};

pub fn GetPreferredBlendMode(allocator: std.mem.Allocator) !c.XrEnvironmentBlendMode {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(m_instance, m_systemId, m_options.parsed.ViewConfigType, 0, &count, null));
    std.debug.assert(count > 0);

    const blendModes = try allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(m_instance, m_systemId, m_options.parsed.ViewConfigType, count, &count, blendModes.ptr));
    for (blendModes) |blendMode| {
        for (m_acceptableBlendModes) |mode| {
            if (blendMode == mode) {
                return blendMode;
            }
        }
    }

    // THROW("No acceptable blend mode returned from the xrEnumerateEnvironmentBlendModes");
    return error.NoAcceptableBlendMode;
}

pub fn InitializeSystem() XrError!void {
    std.debug.assert(m_instance != null);
    std.debug.assert(m_systemId == c.XR_NULL_SYSTEM_ID);

    const systemInfo: c.XrSystemGetInfo = .{
        .type = c.XR_TYPE_SYSTEM_GET_INFO,
        .formFactor = m_options.parsed.FormFactor,
    };
    _ = try XrResult.init(c.xrGetSystem(m_instance, &systemInfo, &m_systemId));

    std.log.debug("Using system {} for form factor {}", .{
        m_systemId,
        m_options.parsed.FormFactor,
    });
    std.debug.assert(m_instance != null);
    std.debug.assert(m_systemId != c.XR_NULL_SYSTEM_ID);
}

fn LogViewConfigurations(allocator: std.mem.Allocator) XrError!void {
    std.debug.assert(m_instance != null);
    std.debug.assert(m_systemId != c.XR_NULL_SYSTEM_ID);

    var viewConfigTypeCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(m_instance, m_systemId, 0, &viewConfigTypeCount, null));
    const viewConfigTypes = try allocator.alloc(c.XrViewConfigurationType, viewConfigTypeCount);
    defer allocator.free(viewConfigTypes);
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(m_instance, m_systemId, viewConfigTypeCount, &viewConfigTypeCount, viewConfigTypes.ptr));
    std.debug.assert(viewConfigTypes.len == viewConfigTypeCount);

    std.log.info("Available View Configuration Types: ({})", .{viewConfigTypeCount});
    for (viewConfigTypes) |viewConfigType| {
        std.log.debug("  View Configuration Type: {} {s}", .{
            viewConfigType,
            if (viewConfigType == m_options.parsed.ViewConfigType) "(Selected)" else "",
        });

        var viewConfigProperties: c.XrViewConfigurationProperties = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_PROPERTIES };
        _ = try XrResult.init(c.xrGetViewConfigurationProperties(m_instance, m_systemId, viewConfigType, &viewConfigProperties));

        std.log.debug("  View configuration FovMutable={s}", .{
            if (viewConfigProperties.fovMutable == c.XR_TRUE) "True" else "False",
        });

        var viewCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(m_instance, m_systemId, viewConfigType, 0, &viewCount, null));
        if (viewCount > 0) {
            const views = try allocator.alloc(c.XrViewConfigurationView, viewCount);
            defer allocator.free(views);
            for (views) |*view| {
                view.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
            }
            _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(m_instance, m_systemId, viewConfigType, viewCount, &viewCount, views.ptr));

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

        try LogEnvironmentBlendMode(allocator, viewConfigType);
    }
}

pub fn InitializeDevice(allocator: std.mem.Allocator) !void {
    try LogViewConfigurations(allocator);

    // The graphics API can initialize the graphics device now that the systemId and instance
    // handle are available.
    try gfx.InitializeDevice(m_instance, m_systemId);
}

fn LogReferenceSpaces(allocator: std.mem.Allocator) XrError!void {
    std.debug.assert(m_session != null);

    var spaceCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(m_session, 0, &spaceCount, null));
    const spaces = try allocator.alloc(c.XrReferenceSpaceType, spaceCount);
    defer allocator.free(spaces);
    _ = try XrResult.init(c.xrEnumerateReferenceSpaces(m_session, spaceCount, &spaceCount, spaces.ptr));

    std.log.info("Available reference spaces: {}", .{spaceCount});
    for (spaces) |space| {
        std.log.debug("  Name: {}", .{space});
    }
}

fn CreateVisualizedSpaces(allocator: std.mem.Allocator) !void {
    std.debug.assert(m_session != null);

    const visualizedSpaces = [_][]const u8{
        "ViewFront", "Local", "Stage", "StageLeft", "StageRight", "StageLeftRotated", "StageRightRotated",
    };

    for (visualizedSpaces) |visualizedSpace| {
        const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(visualizedSpace);
        var space: c.XrSpace = undefined;
        const res = c.xrCreateReferenceSpace(m_session, &referenceSpaceCreateInfo, &space);
        if (c.XR_SUCCEEDED(res)) {
            try m_visualizedSpaces.append(allocator, space);
        } else {
            std.log.warn("Failed to create reference space {s} with error {}", .{ visualizedSpace, res });
        }
    }
}

pub fn InitializeSession(allocator: std.mem.Allocator) XrError!c.XrSession {
    std.debug.assert(m_instance != null);
    std.debug.assert(m_session == null);

    {
        std.log.debug("Creating session...", .{});

        var createInfo: c.XrSessionCreateInfo = .{
            .type = c.XR_TYPE_SESSION_CREATE_INFO,
            .next = gfx.GetGraphicsBinding(),
            .systemId = m_systemId,
        };
        _ = try XrResult.init(c.xrCreateSession(m_instance, &createInfo, &m_session));
    }

    try LogReferenceSpaces(allocator);
    try action.InitializeActions(m_instance, m_session);
    try CreateVisualizedSpaces(allocator);

    {
        const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(m_options.AppSpace.span());
        _ = try XrResult.init(c.xrCreateReferenceSpace(m_session, &referenceSpaceCreateInfo, &m_appSpace));
    }

    return m_session;
}

pub fn CreateSwapchains(allocator: std.mem.Allocator) XrError!void {
    std.debug.assert(m_session != null);
    std.debug.assert(m_swapchains.items.len == 0);
    std.debug.assert(m_configViews.items.len == 0);

    // Read graphics properties for preferred swapchain length and logging.
    var systemProperties: c.XrSystemProperties = .{ .type = c.XR_TYPE_SYSTEM_PROPERTIES };
    _ = try XrResult.init(c.xrGetSystemProperties(m_instance, m_systemId, &systemProperties));

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
    std.debug.assert(m_options.parsed.ViewConfigType == c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO); //, "Unsupported view configuration type");

    // Query and cache view configuration views.
    var viewCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(m_instance, m_systemId, m_options.parsed.ViewConfigType, 0, &viewCount, null));
    try m_configViews.resize(allocator, viewCount);
    for (m_configViews.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
    }
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
        m_instance,
        m_systemId,
        m_options.parsed.ViewConfigType,
        viewCount,
        &viewCount,
        m_configViews.items.ptr,
    ));

    // Create and cache view buffer for xrLocateViews later.
    try m_views.resize(allocator, viewCount);
    for (m_views.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW };
    }

    // Create the swapchain and get the images.
    if (viewCount > 0) {
        // Select a swapchain format.
        var swapchainFormatCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateSwapchainFormats(m_session, 0, &swapchainFormatCount, null));
        const swapchainFormats = try allocator.alloc(i64, swapchainFormatCount);
        defer allocator.free(swapchainFormats);
        _ = try XrResult.init(c.xrEnumerateSwapchainFormats(
            m_session,
            @intCast(swapchainFormats.len),
            &swapchainFormatCount,
            swapchainFormats.ptr,
        ));
        std.debug.assert(swapchainFormatCount == swapchainFormats.len);
        m_colorSwapchainFormat = try gfx.SelectColorSwapchainFormat(allocator, swapchainFormats);

        // Print swapchain formats and the selected one.
        {
            // const swapchainFormatsString: []const u8 = "";
            var out = std.Io.Writer.Allocating.init(allocator);
            defer out.deinit();
            // std.io.Writer を値渡しすると壊れる
            var w: *std.io.Writer = &out.writer;

            for (swapchainFormats) |format| {
                const selected = format == m_colorSwapchainFormat;
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
            defer allocator.free(str);
            std.log.debug("Swapchain Formats: {s}", .{str});
        }

        // Create a swapchain for each view.
        for (m_configViews.items, 0..) |vp, i| {
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
                .format = m_colorSwapchainFormat,
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
            _ = try XrResult.init(c.xrCreateSwapchain(m_session, &swapchainCreateInfo, &swapchain.handle));

            try m_swapchains.append(allocator, swapchain);

            var imageCount: u32 = undefined;
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, 0, &imageCount, null));
            // XXX This should really just return XrSwapchainImageBaseHeader*
            const swapchainImages = try allocator.alloc(*c.XrSwapchainImageBaseHeader, imageCount);
            try gfx.AllocateSwapchainImageStructs(allocator, swapchainImages);
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, imageCount, &imageCount, swapchainImages[0]));

            try m_swapchainImages.put(swapchain.handle, swapchainImages);
        }
    }
}

// Return event if one is available, otherwise return null.
pub fn TryReadNextEvent() ?*c.XrEventDataBaseHeader {
    // It is sufficient to clear the just the XrEventDataBuffer header to
    // XR_TYPE_EVENT_DATA_BUFFER
    const baseHeader: *c.XrEventDataBaseHeader = @ptrCast(&m_eventDataBuffer);
    baseHeader.* = .{ .type = c.XR_TYPE_EVENT_DATA_BUFFER };
    const xr = c.xrPollEvent(m_instance, &m_eventDataBuffer);
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

fn HandleSessionStateChangedEvent(
    stateChangedEvent: *c.XrEventDataSessionStateChanged,
    exitRenderLoop: *bool,
    requestRestart: *bool,
) XrError!void {
    const oldState = m_sessionState;
    m_sessionState = stateChangedEvent.state;

    std.log.info("XrEventDataSessionStateChanged: state {}->{} session={?} time={}", .{
        oldState,
        m_sessionState,
        stateChangedEvent.session,
        stateChangedEvent.time,
    });

    if ((stateChangedEvent.session != null) and (stateChangedEvent.session != m_session)) {
        std.log.err("XrEventDataSessionStateChanged for unknown session", .{});
        return;
    }

    switch (m_sessionState) {
        c.XR_SESSION_STATE_READY => {
            std.debug.assert(m_session != null);
            var sessionBeginInfo: c.XrSessionBeginInfo = .{
                .type = c.XR_TYPE_SESSION_BEGIN_INFO,
            };
            sessionBeginInfo.primaryViewConfigurationType = m_options.parsed.ViewConfigType;
            _ = try XrResult.init(c.xrBeginSession(m_session, &sessionBeginInfo));
            m_sessionRunning = true;
        },
        c.XR_SESSION_STATE_STOPPING => {
            std.debug.assert(m_session != null);
            m_sessionRunning = false;
            _ = try XrResult.init(c.xrEndSession(m_session));
        },
        c.XR_SESSION_STATE_EXITING => {
            exitRenderLoop.* = true;
            // Do not attempt to restart because user closed this session.
            requestRestart.* = false;
        },
        c.XR_SESSION_STATE_LOSS_PENDING => {
            exitRenderLoop.* = true;
            // Poll for a new instance.
            requestRestart.* = true;
        },
        else => {},
    }
}

pub fn PollEvents(
    allocator: std.mem.Allocator,
    exitRenderLoop: *bool,
    requestRestart: *bool,
) !void {
    exitRenderLoop.* = false;
    requestRestart.* = false;

    // Process all pending messages.
    while (TryReadNextEvent()) |event| {
        switch (event.type) {
            c.XR_TYPE_EVENT_DATA_INSTANCE_LOSS_PENDING => {
                const instanceLossPending: *c.XrEventDataInstanceLossPending = @ptrCast(event);
                std.log.warn("XrEventDataInstanceLossPending by {}", .{instanceLossPending.lossTime});
                exitRenderLoop.* = true;
                requestRestart.* = true;
                return;
            },
            c.XR_TYPE_EVENT_DATA_SESSION_STATE_CHANGED => {
                const sessionStateChangedEvent: *c.XrEventDataSessionStateChanged = @ptrCast(event);
                try HandleSessionStateChangedEvent(sessionStateChangedEvent, exitRenderLoop, requestRestart);
            },
            c.XR_TYPE_EVENT_DATA_INTERACTION_PROFILE_CHANGED => {
                try action.LogEvent(allocator, m_session);
            },
            // case XR_TYPE_EVENT_DATA_REFERENCE_SPACE_CHANGE_PENDING:
            else => {
                std.log.debug("Ignoring event type {}", .{event.type});
            },
        }
    }
}

pub fn IsSessionRunning() bool {
    return m_sessionRunning;
}

pub fn IsSessionFocused() bool {
    return m_sessionState == c.XR_SESSION_STATE_FOCUSED;
}

fn RenderLayer(
    allocator: std.mem.Allocator,
    predictedDisplayTime: c.XrTime,
    projectionLayerViews: *std.ArrayList(c.XrCompositionLayerProjectionView),
    layer: *c.XrCompositionLayerProjection,
) !bool {
    var viewState: c.XrViewState = .{ .type = c.XR_TYPE_VIEW_STATE };
    const viewCapacityInput: u32 = @intCast(m_views.items.len);
    var viewCountOutput: u32 = undefined;
    var viewLocateInfo: c.XrViewLocateInfo = .{
        .type = c.XR_TYPE_VIEW_LOCATE_INFO,
        .viewConfigurationType = m_options.parsed.ViewConfigType,
        .displayTime = predictedDisplayTime,
        .space = m_appSpace,
    };

    _ = try XrResult.init(c.xrLocateViews(m_session, &viewLocateInfo, &viewState, viewCapacityInput, &viewCountOutput, m_views.items.ptr));
    if ((viewState.viewStateFlags & c.XR_VIEW_STATE_POSITION_VALID_BIT) == 0 or
        (viewState.viewStateFlags & c.XR_VIEW_STATE_ORIENTATION_VALID_BIT) == 0)
    {
        return false; // There is no valid tracking poses for the views.
    }

    std.debug.assert(viewCountOutput == viewCapacityInput);
    std.debug.assert(viewCountOutput == m_configViews.items.len);
    std.debug.assert(viewCountOutput == m_swapchains.items.len);

    try projectionLayerViews.resize(allocator, viewCountOutput);

    // For each locatable space that we want to visualize, render a 25cm cube.
    var cubes: std.ArrayList(Cube) = .{};
    defer cubes.deinit(allocator);
    for (m_visualizedSpaces.items) |visualizedSpace| {
        var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
        const res = try XrResult.init(c.xrLocateSpace(visualizedSpace, m_appSpace, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                try cubes.append(allocator, .init(spaceLocation.pose, .{ .x = 0.25, .y = 0.25, .z = 0.25 }));
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
        const res = try XrResult.init(c.xrLocateSpace(action.m_input.handSpace[hand], m_appSpace, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                const scale = 0.1 * action.m_input.handScale[hand];
                try cubes.append(allocator, .init(spaceLocation.pose, .{ .x = scale, .y = scale, .z = scale }));
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
    for (m_swapchains.items, 0..) |viewSwapchain, i| {
        // Each view has a separate swapchain which is acquired, rendered to, and released.
        var acquireInfo: c.XrSwapchainImageAcquireInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO };
        var swapchainImageIndex: u32 = undefined;
        _ = try XrResult.init(c.xrAcquireSwapchainImage(viewSwapchain.handle, &acquireInfo, &swapchainImageIndex));

        var waitInfo: c.XrSwapchainImageWaitInfo = .{
            .type = c.XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO,
            .timeout = c.XR_INFINITE_DURATION,
        };
        _ = try XrResult.init(c.xrWaitSwapchainImage(viewSwapchain.handle, &waitInfo));

        projectionLayerViews.items[i] = .{
            .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW,
            .pose = m_views.items[i].pose,
            .fov = m_views.items[i].fov,
            .subImage = .{
                .swapchain = viewSwapchain.handle,
                .imageRect = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = @intCast(viewSwapchain.width), .height = @intCast(viewSwapchain.height) },
                },
            },
        };

        const entry = m_swapchainImages.get(viewSwapchain.handle).?;
        const swapchainImage: *c.XrSwapchainImageBaseHeader = entry[swapchainImageIndex];
        try gfx.RenderView(&projectionLayerViews.items[i], swapchainImage, m_colorSwapchainFormat, cubes.items);

        var releaseInfo: c.XrSwapchainImageReleaseInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO };
        _ = try XrResult.init(c.xrReleaseSwapchainImage(viewSwapchain.handle, &releaseInfo));
    }

    layer.space = m_appSpace;
    layer.layerFlags = if (m_options.parsed.EnvironmentBlendMode == c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND)
        c.XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT | c.XR_COMPOSITION_LAYER_UNPREMULTIPLIED_ALPHA_BIT
    else
        0;
    layer.viewCount = @intCast(projectionLayerViews.items.len);
    layer.views = projectionLayerViews.items.ptr;
    return true;
}

pub fn RenderFrame(allocator: std.mem.Allocator) XrError!void {
    std.debug.assert(m_session != null);

    var frameWaitInfo: c.XrFrameWaitInfo = .{ .type = c.XR_TYPE_FRAME_WAIT_INFO };
    var frameState: c.XrFrameState = .{ .type = c.XR_TYPE_FRAME_STATE };
    _ = try XrResult.init(c.xrWaitFrame(m_session, &frameWaitInfo, &frameState));

    var frameBeginInfo: c.XrFrameBeginInfo = .{ .type = c.XR_TYPE_FRAME_BEGIN_INFO };
    _ = try XrResult.init(c.xrBeginFrame(m_session, &frameBeginInfo));

    var layers: std.ArrayList(*c.XrCompositionLayerBaseHeader) = .{};
    defer layers.deinit(allocator);
    var layer: c.XrCompositionLayerProjection = .{ .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION };
    var projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{};
    defer projectionLayerViews.deinit(allocator);
    if (frameState.shouldRender == c.XR_TRUE) {
        if (try RenderLayer(
            allocator,
            frameState.predictedDisplayTime,
            &projectionLayerViews,
            &layer,
        )) {
            try layers.append(allocator, @ptrCast(&layer));
        }
    }

    var frameEndInfo: c.XrFrameEndInfo = .{
        .type = c.XR_TYPE_FRAME_END_INFO,
        .displayTime = frameState.predictedDisplayTime,
        .environmentBlendMode = m_options.parsed.EnvironmentBlendMode,
        .layerCount = @intCast(layers.items.len),
        .layers = layers.items.ptr,
    };
    _ = try XrResult.init(c.xrEndFrame(m_session, &frameEndInfo));
}
