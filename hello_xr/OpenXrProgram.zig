const std = @import("std");
const builtin = @import("builtin");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const c = @import("c");
const Cube = @import("Cube.zig");
const geometry = @import("geometry.zig");
const Options = @import("Options.zig");
const Renderer = @import("gfx/RendererOpenGL4.zig");

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
layer: c.XrCompositionLayerProjection = .{ .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION },

swapchains: std.ArrayList(Swapchain) = .{},
configViews: std.ArrayList(c.XrViewConfigurationView) = .{},
swapchainImages: std.AutoHashMap(c.XrSwapchain, []*c.XrSwapchainImageBaseHeader),
views: std.ArrayList(c.XrView) = .{},
colorSwapchainFormat: i64 = -1,

projectionLayerViews: std.ArrayList(c.XrCompositionLayerProjectionView) = .{},

swapchainImageBuffers: std.ArrayList([]@TypeOf(gfx.swapchain_image)) = .{},
fn allocateSwapchainImageStructs(
    this: *@This(),
    swapchainImageBase: []*c.XrSwapchainImageBaseHeader,
) !void {
    // Allocate and initialize the buffer of image structs
    // (must be sequential in memory for xrEnumerateSwapchainImages).
    // Return back an array of pointers to each swapchain image struct
    // so the consumer doesn't need to know the type/size.
    const swapchainImageBuffer = try this.allocator.alloc(@TypeOf(gfx.swapchain_image), swapchainImageBase.len);
    for (swapchainImageBuffer) |*buf| {
        buf.* = gfx.swapchain_image;
    }
    for (swapchainImageBuffer, 0..) |*buf, i| {
        swapchainImageBase[i] = @ptrCast(buf);
    }
    // Keep the buffer alive by moving it into the list of buffers.
    try this.swapchainImageBuffers.append(this.allocator, swapchainImageBuffer);
}

pub fn init(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    session: c.XrSession,
    view_config_type: c.XrViewConfigurationType,
    app_space: Options.ReferenceSpaceType,
) !@This() {
    std.log.info("## OpenXrProgram.init ##", .{});

    var this: @This() = .{
        .allocator = allocator,
        .instance = instance,
        .systemId = systemId,
        .session = session,
        .swapchainImages = .init(allocator),
    };

    const referenceSpaceCreateInfo = app_space.makeXrReferenceSpaceCreateInfo();
    _ = try XrResult.init(c.xrCreateReferenceSpace(session, &referenceSpaceCreateInfo, &this.appSpace));

    try this.CreateSwapchains(view_config_type);

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## OpenXrProgram.deinit ##", .{});

    for (this.swapchainImageBuffers.items) |image| {
        this.allocator.free(image);
    }
    this.swapchainImageBuffers.deinit(this.allocator);

    {
        var it = this.swapchainImages.iterator();
        while (it.next()) |item| {
            this.allocator.free(item.value_ptr.*);
        }
        this.swapchainImages.deinit();
    }

    this.projectionLayerViews.deinit(this.allocator);
    this.configViews.deinit(this.allocator);

    for (this.swapchains.items) |swapchain| {
        _ = c.xrDestroySwapchain(swapchain.handle);
    }
    this.swapchains.deinit(this.allocator);

    this.views.deinit(this.allocator);

    //     //     if (m_appSpace != XR_NULL_HANDLE) {
    //     //         xrDestroySpace(m_appSpace);
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

var version_str: [64]u8 = undefined;

pub fn CreateSwapchains(this: *@This(), view_config_type: c.XrViewConfigurationType) XrError!void {
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
            try this.allocateSwapchainImageStructs(swapchainImages);
            _ = try XrResult.init(c.xrEnumerateSwapchainImages(swapchain.handle, imageCount, &imageCount, swapchainImages[0]));

            try this.swapchainImages.put(swapchain.handle, swapchainImages);
        }
    }
}

pub fn renderLayer(
    this: *@This(),
    blend_mode: c.XrEnvironmentBlendMode,
    cubes: []const Cube,
    renderer: *Renderer,
) !*c.XrCompositionLayerBaseHeader {
    // std.debug.assert(viewCountOutput == viewCapacityInput);
    // std.debug.assert(viewCountOutput == m_configViews.items.len);
    // std.debug.assert(viewCountOutput == m_swapchains.items.len);

    try this.projectionLayerViews.resize(this.allocator, this.views.items.len);

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
        try renderer.renderView(
            &this.projectionLayerViews.items[i],
            swapchainImage,
            this.colorSwapchainFormat,
            Options.GetBackgroundClearColor(blend_mode),
            cubes,
        );

        var releaseInfo: c.XrSwapchainImageReleaseInfo = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO };
        _ = try XrResult.init(c.xrReleaseSwapchainImage(viewSwapchain.handle, &releaseInfo));
    }

    this.layer = .{
        .type = c.XR_TYPE_COMPOSITION_LAYER_PROJECTION,
        .space = this.appSpace,
        .layerFlags = if (blend_mode == c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND)
            c.XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT | c.XR_COMPOSITION_LAYER_UNPREMULTIPLIED_ALPHA_BIT
        else
            0,
        .viewCount = @intCast(this.projectionLayerViews.items.len),
        .views = this.projectionLayerViews.items.ptr,
    };
    return @ptrCast(&this.layer);
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
