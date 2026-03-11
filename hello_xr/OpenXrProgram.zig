const std = @import("std");
const builtin = @import("builtin");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const c = @import("c");
const Options = @import("Options.zig");

const Swapchain = struct {
    handle: c.XrSwapchain,
    width: u32,
    height: u32,
};

allocator: std.mem.Allocator,
instance: c.XrInstance,
systemId: c.XrSystemId,
session: c.XrSession,
appSpace: c.XrSpace = null,

swapchains: std.ArrayList(Swapchain) = .{},
configViews: std.ArrayList(c.XrViewConfigurationView) = .{},
views: std.ArrayList(c.XrView) = .{},
colorSwapchainFormat: i64,
sampleCount: u32,

pub fn init(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    session: c.XrSession,
    view_config_type: c.XrViewConfigurationType,
    colorSwapchainFormat: i64,
    sampleCount: u32,
    app_space: Options.ReferenceSpaceType,
) !@This() {
    std.log.info("## OpenXrProgram.init ##", .{});

    var this: @This() = .{
        .allocator = allocator,
        .instance = instance,
        .systemId = systemId,
        .session = session,
        .colorSwapchainFormat = colorSwapchainFormat,
        .sampleCount = sampleCount,
    };

    const referenceSpaceCreateInfo = app_space.makeXrReferenceSpaceCreateInfo();
    _ = try XrResult.init(c.xrCreateReferenceSpace(session, &referenceSpaceCreateInfo, &this.appSpace));

    try this.CreateSwapchains(view_config_type);

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## OpenXrProgram.deinit ##", .{});

    this.configViews.deinit(this.allocator);

    for (this.swapchains.items) |swapchain| {
        _ = c.xrDestroySwapchain(swapchain.handle);
    }
    this.swapchains.deinit(this.allocator);

    this.views.deinit(this.allocator);

    if (this.appSpace != null) {
        _ = c.xrDestroySpace(this.appSpace);
    }
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

var version_str: [64]u8 = undefined;

pub fn CreateSwapchains(
    this: *@This(),
    view_config_type: c.XrViewConfigurationType,
) XrError!void {
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
    // Note: No other view configurations exist at the time this code was written. If this
    // condition is not met, the project will need to be audited to see how support should be
    // added.
    // std.debug.assert(this.options.ViewConfigType == c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO); //, "Unsupported view configuration type");

    // Query and cache view configuration views.
    var viewCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
        this.instance,
        this.systemId,
        view_config_type,
        0,
        &viewCount,
        null,
    ));
    try this.configViews.resize(this.allocator, viewCount);
    for (this.configViews.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
    }
    _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
        this.instance,
        this.systemId,
        view_config_type,
        viewCount,
        &viewCount,
        this.configViews.items.ptr,
    ));

    // Create and cache view buffer for xrLocateViews later.
    try this.views.resize(this.allocator, viewCount);
    for (this.views.items) |*item| {
        item.* = .{ .type = c.XR_TYPE_VIEW };
    }

    // Create a swapchain for each view.
    for (this.configViews.items, 0..) |vp, i| {
        std.log.debug("Creating swapchain for view {} with dimensions Width={} Height={} SampleCount={}", .{
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
            .sampleCount = this.sampleCount,
            .usageFlags = c.XR_SWAPCHAIN_USAGE_SAMPLED_BIT | c.XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT,
        };

        var swapchain: Swapchain = .{
            .handle = null,
            .width = swapchainCreateInfo.width,
            .height = swapchainCreateInfo.height,
        };
        _ = try XrResult.init(c.xrCreateSwapchain(this.session, &swapchainCreateInfo, &swapchain.handle));

        try this.swapchains.append(this.allocator, swapchain);
    }
}

pub const AcquireInfo = struct {
    handle: c.XrSwapchain,
    swapchainImageIndex: u32,
    projection_layer_view: c.XrCompositionLayerProjectionView,
};

pub fn acquireSwapchain(this: *@This(), view_index: usize) !AcquireInfo {
    const swapchain = this.swapchains.items[view_index];

    // Render view to the appropriate part of the swapchain image.
    // Each view has a separate swapchain which is acquired, rendered to, and released.
    var acquireInfo: c.XrSwapchainImageAcquireInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO };
    var swapchainImageIndex: u32 = undefined;
    _ = try XrResult.init(c.xrAcquireSwapchainImage(swapchain.handle, &acquireInfo, &swapchainImageIndex));

    var waitInfo: c.XrSwapchainImageWaitInfo = .{
        .type = c.XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO,
        .timeout = c.XR_INFINITE_DURATION,
    };
    _ = try XrResult.init(c.xrWaitSwapchainImage(swapchain.handle, &waitInfo));

    return .{
        .handle = swapchain.handle,
        .swapchainImageIndex = swapchainImageIndex,
        .projection_layer_view = .{
            .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION_VIEW,
            .pose = this.views.items[view_index].pose,
            .fov = this.views.items[view_index].fov,
            .subImage = .{
                .swapchain = swapchain.handle,
                .imageRect = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = @intCast(swapchain.width), .height = @intCast(swapchain.height) },
                },
            },
        },
    };
}

pub fn releaseSwapchain(this: *@This(), handle: c.XrSwapchain) !void {
    _ = this;
    var releaseInfo: c.XrSwapchainImageReleaseInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO };
    _ = try XrResult.init(c.xrReleaseSwapchainImage(handle, &releaseInfo));
}

pub fn endFrame(
    this: *@This(),
    predictedDisplayTime: c.XrTime,
    blend_mode: c.XrEnvironmentBlendMode,
    maybe_layer: ?*c.XrCompositionLayerBaseHeader,
) !void {
    var frameEndInfo: c.XrFrameEndInfo = .{
        .type = c.XR_TYPE_FRAME_END_INFO,
        .displayTime = predictedDisplayTime,
        .environmentBlendMode = blend_mode,
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

pub fn locate(
    this: *@This(),
    predictedDisplayTime: c.XrTime,
    view_config_type: c.XrViewConfigurationType,
) !bool {
    var viewState: c.XrViewState = .{ .type = c.XR_TYPE_VIEW_STATE };
    const viewCapacityInput: u32 = @intCast(this.views.items.len);
    var viewCountOutput: u32 = undefined;
    var viewLocateInfo: c.XrViewLocateInfo = .{
        .type = c.XR_TYPE_VIEW_LOCATE_INFO,
        .viewConfigurationType = view_config_type,
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
