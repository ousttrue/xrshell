const c = @import("c");

Pose: c.XrPosef,
Scale: c.XrVector3f,

pub fn init(pose: c.XrPosef, scale: c.XrVector3f) @This() {
    return .{
        .Pose = pose,
        .Scale = scale,
    };
}
