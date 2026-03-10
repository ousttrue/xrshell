const std = @import("std");
const c = @import("c");

const Float3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
};

pub const Vertex = struct {
    Position: Float3,
    Color: Float3,
};

const Red = Float3{ .x = 1, .y = 0, .z = 0 };
const DarkRed = Float3{ .x = 0.25, .y = 0, .z = 0 };
const Green = Float3{ .x = 0, .y = 1, .z = 0 };
const DarkGreen = Float3{ .x = 0, .y = 0.25, .z = 0 };
const Blue = Float3{ .x = 0, .y = 0, .z = 1 };
const DarkBlue = Float3{ .x = 0, .y = 0, .z = 0.25 };

// Vertices for a 1x1x1 meter cube. (Left/Right, Top/Bottom, Front/Back)
const LBB = Float3{ .x = -0.5, .y = -0.5, .z = -0.5 };
const LBF = Float3{ .x = -0.5, .y = -0.5, .z = 0.5 };
const LTB = Float3{ .x = -0.5, .y = 0.5, .z = -0.5 };
const LTF = Float3{ .x = -0.5, .y = 0.5, .z = 0.5 };
const RBB = Float3{ .x = 0.5, .y = -0.5, .z = -0.5 };
const RBF = Float3{ .x = 0.5, .y = -0.5, .z = 0.5 };
const RTB = Float3{ .x = 0.5, .y = 0.5, .z = -0.5 };
const RTF = Float3{ .x = 0.5, .y = 0.5, .z = 0.5 };

fn CUBE_SIDE(
    V1: Float3,
    V2: Float3,
    V3: Float3,
    V4: Float3,
    V5: Float3,
    V6: Float3,
    COLOR: Float3,
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
