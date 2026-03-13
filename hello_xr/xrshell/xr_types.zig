const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrError = xr_result.XrError;
const XrResult = xr_result.XrResult;

/// https://registry.khronos.org/OpenXR/specs/1.0/man/html/XrReferenceSpaceType.html
pub const ReferenceSpaceType = enum(u32) {
    VIEW = 1,
    LOCAL = 2,
    STAGE = 3,
    /// Provided by XR_MSFT_unbounded_reference_space
    UNBOUNDED_MSFT = 1000038000,
    /// Provided by XR_VARJO_foveated_rendering
    COMBINED_EYE_VARJO = 1000121000,
    /// Provided by XR_ML_localization_map
    LOCALIZATION_MAP_ML = 1000139000,
    /// Provided by XR_EXT_local_floor
    TYPE_LOCAL_FLOOR_EXT = 1000426000,

    pub fn log(allocator: std.mem.Allocator, session: c.XrSession) XrError!void {
        var spaceCount: u32 = undefined;
        _ = try XrResult.init(c.xrEnumerateReferenceSpaces(session, 0, &spaceCount, null));
        const spaces = try allocator.alloc(c.XrReferenceSpaceType, spaceCount);
        defer allocator.free(spaces);
        _ = try XrResult.init(c.xrEnumerateReferenceSpaces(session, spaceCount, &spaceCount, spaces.ptr));

        std.log.debug("Available reference spaces: {}", .{spaceCount});
        for (spaces) |*space| {
            const s: *const ReferenceSpaceType = @ptrCast(space);
            std.log.debug("  Name: {}", .{s.*});
        }
    }
};

pub const AppSpaceType = enum {
    View,
    ViewFront,
    Local,
    Stage,
    StageLeft,
    StageRight,
    StageLeftRotated,
    StageRightRotated,

    pub fn makeXrReferenceSpaceCreateInfo(this: @This()) c.XrReferenceSpaceCreateInfo {
        var referenceSpaceCreateInfo: c.XrReferenceSpaceCreateInfo = .{
            .type = c.XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
            .poseInReferenceSpace = Identity(),
        };
        switch (this) {
            .View => {
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_VIEW;
            },
            .ViewFront => {
                // Render head-locked 2m in front of device.
                referenceSpaceCreateInfo.poseInReferenceSpace = Translation(.{ .x = 0.0, .y = 0.0, .z = -2.0 });
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_VIEW;
            },
            .Local => {
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_LOCAL;
            },
            .Stage => {
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
            },
            .StageLeft => {
                referenceSpaceCreateInfo.poseInReferenceSpace = RotateCCWAboutYAxis(0.0, .{ .x = -2.0, .y = 0.0, .z = -2.0 });
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
            },
            .StageRight => {
                referenceSpaceCreateInfo.poseInReferenceSpace = RotateCCWAboutYAxis(0.0, .{ .x = 2.0, .y = 0.0, .z = -2.0 });
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
            },
            .StageLeftRotated => {
                referenceSpaceCreateInfo.poseInReferenceSpace = RotateCCWAboutYAxis(3.14 / 3.0, .{ .x = -2.0, .y = 0.5, .z = -2.0 });
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
            },
            .StageRightRotated => {
                referenceSpaceCreateInfo.poseInReferenceSpace = RotateCCWAboutYAxis(-3.14 / 3.0, .{ .x = 2.0, .y = 0.5, .z = -2.0 });
                referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
            },
        }
        return referenceSpaceCreateInfo;
    }

    pub fn Identity() c.XrPosef {
        return .{
            .orientation = .{ .w = 1 },
        };
    }

    pub fn Translation(translation: c.XrVector3f) c.XrPosef {
        var t = Identity();
        t.position = translation;
        return t;
    }

    pub fn RotateCCWAboutYAxis(radians: f32, translation: c.XrVector3f) c.XrPosef {
        var t = Identity();
        t.orientation.x = 0.0;
        t.orientation.y = @sin(radians * 0.5);
        t.orientation.z = 0.0;
        t.orientation.w = @cos(radians * 0.5);
        t.position = translation;
        return t;
    }
};

/// https://registry.khronos.org/OpenXR/specs/1.1/man/html/XrSessionState.html
pub const SessionState = enum(u32) {
    UNKNOWN = 0,
    IDLE = 1,
    READY = 2,
    SYNCHRONIZED = 3,
    VISIBLE = 4,
    FOCUSED = 5,
    STOPPING = 6,
    LOSS_PENDING = 7,
    EXITING = 8,
};
