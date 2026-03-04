const std = @import("std");
const c = @import("gfx/gfxwrapper_opengl_wayland.zig").c;

// namespace Math {
// namespace Pose {
fn Identity() c.XrPosef {
    return .{
        .orientation = .{ .w = 1 },
    };
}

// XrPosef Translation(const XrVector3f& translation) {
//     XrPosef t = Identity();
//     t.position = translation;
//     return t;
// }
//
// XrPosef RotateCCWAboutYAxis(float radians, XrVector3f translation) {
//     XrPosef t = Identity();
//     t.orientation.x = 0.f;
//     t.orientation.y = std::sin(radians * 0.5f);
//     t.orientation.z = 0.f;
//     t.orientation.w = std::cos(radians * 0.5f);
//     t.position = translation;
//     return t;
// }
// }  // namespace Pose
// }  // namespace Math

pub fn GetXrReferenceSpaceCreateInfo(referenceSpaceTypeStr: []const u8) c.XrReferenceSpaceCreateInfo {
    var referenceSpaceCreateInfo: c.XrReferenceSpaceCreateInfo = .{
        .type = c.XR_TYPE_REFERENCE_SPACE_CREATE_INFO,
        .poseInReferenceSpace = Identity(),
    };
    if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "View")) {
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_VIEW;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "ViewFront")) {
        // Render head-locked 2m in front of device.
        // referenceSpaceCreateInfo.poseInReferenceSpace = Math::Pose::Translation({0.f, 0.f, -2.f}),
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_VIEW;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "Local")) {
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_LOCAL;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "Stage")) {
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "StageLeft")) {
        // referenceSpaceCreateInfo.poseInReferenceSpace = Math::Pose::RotateCCWAboutYAxis(0.f, {-2.f, 0.f, -2.f});
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "StageRight")) {
        // referenceSpaceCreateInfo.poseInReferenceSpace = Math::Pose::RotateCCWAboutYAxis(0.f, {2.f, 0.f, -2.f});
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "StageLeftRotated")) {
        // referenceSpaceCreateInfo.poseInReferenceSpace = Math::Pose::RotateCCWAboutYAxis(3.14f / 3.f, {-2.f, 0.5f, -2.f});
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
    } else if (std.ascii.eqlIgnoreCase(referenceSpaceTypeStr, "StageRightRotated")) {
        // referenceSpaceCreateInfo.poseInReferenceSpace = Math::Pose::RotateCCWAboutYAxis(-3.14f / 3.f, {2.f, 0.5f, -2.f});
        referenceSpaceCreateInfo.referenceSpaceType = c.XR_REFERENCE_SPACE_TYPE_STAGE;
    } else {
        std.log.err("{s}", .{referenceSpaceTypeStr});
        @panic("Unknown reference space type");
    }
    return referenceSpaceCreateInfo;
}
