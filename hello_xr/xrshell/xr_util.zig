const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrResult = xr_result.XrResult;
const XrError = xr_result.XrError;

pub fn getXrVersionString(buf: []u8, ver: c.XrVersion) []const u8 {
    return std.fmt.bufPrint(buf, "{}.{}.{}", .{
        c.XR_VERSION_MAJOR(ver),
        c.XR_VERSION_MINOR(ver),
        c.XR_VERSION_PATCH(ver),
    }) catch @panic("OOM");
}

pub fn getPreferredBlendMode(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    view_config_type: c.XrViewConfigurationType,
) XrError!c.XrEnvironmentBlendMode {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        instance,
        systemId,
        view_config_type,
        0,
        &count,
        null,
    ));
    const blendModes = try allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        instance,
        systemId,
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
                try logViewConfigurations(allocator, instance, systemId, view_config_type, blendMode);

                return blendMode;
            }
        }
    }

    // THROW("No acceptable blend mode returned from the xrEnumerateEnvironmentBlendModes");
    @panic("NoAcceptableBlendMode");
}

fn logViewConfigurations(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    view_config_type: c.XrViewConfigurationType,
    blend_mode: c.XrEnvironmentBlendMode,
) XrError!void {
    var viewConfigTypeCount: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(
        instance,
        systemId,
        0,
        &viewConfigTypeCount,
        null,
    ));
    const viewConfigTypes = try allocator.alloc(c.XrViewConfigurationType, viewConfigTypeCount);
    defer allocator.free(viewConfigTypes);
    _ = try XrResult.init(c.xrEnumerateViewConfigurations(
        instance,
        systemId,
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
            instance,
            systemId,
            viewConfigType,
            &viewConfigProperties,
        ));

        std.log.debug("  View configuration FovMutable={s}", .{
            if (viewConfigProperties.fovMutable == c.XR_TRUE) "True" else "False",
        });

        var viewCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
            instance,
            systemId,
            viewConfigType,
            0,
            &viewCount,
            null,
        ));
        if (viewCount > 0) {
            const views = try allocator.alloc(c.XrViewConfigurationView, viewCount);
            defer allocator.free(views);
            for (views) |*view| {
                view.* = .{ .type = c.XR_TYPE_VIEW_CONFIGURATION_VIEW };
            }
            _ = try XrResult.init(c.xrEnumerateViewConfigurationViews(
                instance,
                systemId,
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

        try logEnvironmentBlendMode(allocator, instance, systemId, view_config_type, blend_mode);
    }
}

fn logEnvironmentBlendMode(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    systemId: c.XrSystemId,
    view_config_type: c.XrViewConfigurationType,
    blend_mode: c.XrEnvironmentBlendMode,
) XrError!void {
    var count: u32 = undefined;
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        instance,
        systemId,
        view_config_type,
        0,
        &count,
        null,
    ));
    std.debug.assert(count > 0);

    std.log.debug("Available Environment Blend Mode count : ({})", .{count});

    const blendModes = try allocator.alloc(c.XrEnvironmentBlendMode, count);
    defer allocator.free(blendModes);
    _ = try XrResult.init(c.xrEnumerateEnvironmentBlendModes(
        instance,
        systemId,
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
