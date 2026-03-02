const c = @import("c.zig").openxr;
const XrVector3f = c.XrVector3f;

pub const Vertex = struct {
    Position: XrVector3f,
    Color: XrVector3f,
};

const Red = XrVector3f{ .x = 1, .y = 0, .z = 0 };
const DarkRed = XrVector3f{ .x = 0.25, .y = 0, .z = 0 };
const Green = XrVector3f{ .x = 0, .y = 1, .z = 0 };
const DarkGreen = XrVector3f{ .x = 0, .y = 0.25, .z = 0 };
const Blue = XrVector3f{ .x = 0, .y = 0, .z = 1 };
const DarkBlue = XrVector3f{ .x = 0, .y = 0, .z = 0.25 };

// Vertices for a 1x1x1 meter cube. (Left/Right, Top/Bottom, Front/Back)
const LBB = XrVector3f{ .x = -0.5, .y = -0.5, .z = -0.5 };
const LBF = XrVector3f{ .x = -0.5, .y = -0.5, .z = 0.5 };
const LTB = XrVector3f{ .x = -0.5, .y = 0.5, .z = -0.5 };
const LTF = XrVector3f{ .x = -0.5, .y = 0.5, .z = 0.5 };
const RBB = XrVector3f{ .x = 0.5, .y = -0.5, .z = -0.5 };
const RBF = XrVector3f{ .x = 0.5, .y = -0.5, .z = 0.5 };
const RTB = XrVector3f{ .x = 0.5, .y = 0.5, .z = -0.5 };
const RTF = XrVector3f{ .x = 0.5, .y = 0.5, .z = 0.5 };

fn CUBE_SIDE(
    V1: XrVector3f,
    V2: XrVector3f,
    V3: XrVector3f,
    V4: XrVector3f,
    V5: XrVector3f,
    V6: XrVector3f,
    COLOR: XrVector3f,
) [6]Vertex {
    return .{
        .{ .Position = V1, .Color = COLOR },
        .{ .Position = V2, .Color = COLOR },
        .{ .Position = V3, .Color = COLOR },
        .{ .Position = V4, .Color = COLOR },
        .{ .Position = V5, .Color = COLOR },
        .{ .Position = V6, .Color = COLOR },
    };
}

pub const c_cubeVertices =
    CUBE_SIDE(LTB, LBF, LBB, LTB, LTF, LBF, DarkRed) ++ // -X
    CUBE_SIDE(RTB, RBB, RBF, RTB, RBF, RTF, Red) ++ // +X
    CUBE_SIDE(LBB, LBF, RBF, LBB, RBF, RBB, DarkGreen) ++ // -Y
    CUBE_SIDE(LTB, RTB, RTF, LTB, RTF, LTF, Green) ++ // +Y
    CUBE_SIDE(LBB, RBB, RTB, LBB, RTB, LTB, DarkBlue) ++ // -Z
    CUBE_SIDE(LBF, LTF, RTF, LBF, RTF, RBF, Blue) // +Z
;

// Winding order is clockwise. Each side uses a different color.
pub const c_cubeIndices = [_]u16{
    0, 1, 2, 3, 4, 5, // -X
    6, 7, 8, 9, 10, 11, // +X
    12, 13, 14, 15, 16, 17, // -Y
    18, 19, 20, 21, 22, 23, // +Y
    24, 25, 26, 27, 28, 29, // -Z
    30, 31, 32, 33, 34, 35, // +Z
};
