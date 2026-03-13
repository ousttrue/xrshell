const std = @import("std");
const c = @import("c");
const xr_linear = @import("xr_linear.zig");
const Cube = @import("../Cube.zig");
const sokol = @import("sokol");
const shd = @import("shd");

allocator: std.mem.Allocator,
imageMap: std.AutoHashMap(u32, sokol.gfx.Attachments),

state: struct {
    pip: sokol.gfx.Pipeline = .{},
    bind: sokol.gfx.Bindings = .{},
} = .{},

pub fn init(allocator: std.mem.Allocator) @This() {
    std.log.info("## SokolRenderer.init ##", .{});

    var this: @This() = .{
        .allocator = allocator,
        .imageMap = .init(allocator),
    };

    sokol.gfx.setup(.{
        .logger = .{ .func = sokol.log.func },
        .environment = .{
            .defaults = .{
                .color_format = .RGBA8,
                .depth_format = .DEPTH_STENCIL,
                .sample_count = 1,
            },
        },
    });
    std.debug.assert(sokol.gfx.isvalid());

    const s = 0.5;
    this.state.bind.vertex_buffers[0] = sokol.gfx.makeBuffer(.{
        .data = sokol.gfx.asRange(&[_]f32{
            // positions        colors
            -s, -s, -s, 1.0, 0.0, 0.0, 1.0,
            s,  -s, -s, 1.0, 0.0, 0.0, 1.0,
            s,  s,  -s, 1.0, 0.0, 0.0, 1.0,
            -s, s,  -s, 1.0, 0.0, 0.0, 1.0,

            -s, -s, s,  0.0, 1.0, 0.0, 1.0,
            s,  -s, s,  0.0, 1.0, 0.0, 1.0,
            s,  s,  s,  0.0, 1.0, 0.0, 1.0,
            -s, s,  s,  0.0, 1.0, 0.0, 1.0,

            -s, -s, -s, 0.0, 0.0, 1.0, 1.0,
            -s, s,  -s, 0.0, 0.0, 1.0, 1.0,
            -s, s,  s,  0.0, 0.0, 1.0, 1.0,
            -s, -s, s,  0.0, 0.0, 1.0, 1.0,

            s,  -s, -s, 1.0, 0.5, 0.0, 1.0,
            s,  s,  -s, 1.0, 0.5, 0.0, 1.0,
            s,  s,  s,  1.0, 0.5, 0.0, 1.0,
            s,  -s, s,  1.0, 0.5, 0.0, 1.0,

            -s, -s, -s, 0.0, 0.5, 1.0, 1.0,
            -s, -s, s,  0.0, 0.5, 1.0, 1.0,
            s,  -s, s,  0.0, 0.5, 1.0, 1.0,
            s,  -s, -s, 0.0, 0.5, 1.0, 1.0,

            -s, s,  -s, 1.0, 0.0, 0.5, 1.0,
            -s, s,  s,  1.0, 0.0, 0.5, 1.0,
            s,  s,  s,  1.0, 0.0, 0.5, 1.0,
            s,  s,  -s, 1.0, 0.0, 0.5, 1.0,
        }),
    });

    // cube index buffer
    this.state.bind.index_buffer = sokol.gfx.makeBuffer(.{
        .usage = .{ .index_buffer = true },
        .data = sokol.gfx.asRange(&[_]u16{
            0,  1,  2,  0,  2,  3,
            6,  5,  4,  7,  6,  4,
            8,  9,  10, 8,  10, 11,
            14, 13, 12, 15, 14, 12,
            16, 17, 18, 16, 18, 19,
            22, 21, 20, 23, 22, 20,
        }),
    });

    // shader and pipeline object
    this.state.pip = sokol.gfx.makePipeline(.{
        .shader = sokol.gfx.makeShader(shd.cubeShaderDesc(sokol.gfx.queryBackend())),
        .layout = init: {
            var l = sokol.gfx.VertexLayoutState{};
            l.attrs[shd.ATTR_cube_position].format = .FLOAT3;
            l.attrs[shd.ATTR_cube_color0].format = .FLOAT4;
            break :init l;
        },
        .index_type = .UINT16,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
            .pixel_format = .DEPTH,
        },
        .cull_mode = .BACK,
    });

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## SokolRenderer.deinit ##", .{});
    this.imageMap.deinit();
    sokol.gfx.shutdown();
}

pub fn renderView(
    this: *@This(),
    layerView: *const c.XrCompositionLayerProjectionView,
    color_texture: u32,
    swapchainFormat: i64,
    depth_format: c.GLint,
    clear_color: [4]f32,
    vp: xr_linear.XrMatrix4x4f,
    cubes: []const Cube,
) !void {
    // _ = this; // autofix
    // _ = layerView; // autofix
    // _ = color_texture; // autofix
    _ = swapchainFormat; // autofix
    _ = depth_format; // autofix
    // _ = clear_color; // autofix
    // _ = vp; // autofix
    // _ = cubes; // autofix

    sokol.gfx.beginPass(.{
        .action = .{
            .colors = .{
                .{
                    .load_action = .CLEAR,
                    .clear_value = .{
                        .r = clear_color[0],
                        .g = clear_color[1],
                        .b = clear_color[2],
                        .a = clear_color[3],
                    },
                },
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
            },
        },
        .attachments = this.getAttachment(
            color_texture,
            layerView.subImage.imageRect.extent.width,
            layerView.subImage.imageRect.extent.height,
        ),
    });

    {
        for (cubes) |cube| {
            sokol.gfx.applyPipeline(this.state.pip);
            sokol.gfx.applyBindings(this.state.bind);

            const model = xr_linear.XrMatrix4x4f_CreateTranslationRotationScale(
                cube.Pose.position,
                cube.Pose.orientation,
                cube.Scale,
            );
            const mvp = xr_linear.XrMatrix4x4f_Multiply(vp, model);

            var vs_params = shd.VsParams{
                .mvp = mvp.m,
            };

            sokol.gfx.applyUniforms(shd.UB_vs_params, sokol.gfx.asRange(&vs_params));
            sokol.gfx.draw(0, 36, 1);
        }
    }

    sokol.gfx.endPass();
    sokol.gfx.commit();
}

fn getAttachment(this: *@This(), colorTexture: u32, width: i32, height: i32) sokol.gfx.Attachments {
    const attachments = this.imageMap.get(colorTexture) orelse blk: {
        const color_img = sokol.gfx.makeImage(.{
            .usage = .{ .color_attachment = true },
            .width = width,
            .height = height,
            .sample_count = 1,
            .pixel_format = .RGBA8,
            .gl_textures = .{ colorTexture, 0 },
        });

        const depth_img = sokol.gfx.makeImage(.{
            .usage = .{ .depth_stencil_attachment = true },
            .width = width,
            .height = height,
            .sample_count = 1,
            .pixel_format = .DEPTH,
        });

        const new_attachments = sokol.gfx.Attachments{
            .colors = .{
                sokol.gfx.makeView(.{ .color_attachment = .{ .image = color_img } }),
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
            },
            .depth_stencil = sokol.gfx.makeView(.{ .depth_stencil_attachment = .{ .image = depth_img } }),
        };

        this.imageMap.put(colorTexture, new_attachments) catch @panic("OOM");

        break :blk new_attachments;
    };
    return attachments;
}
