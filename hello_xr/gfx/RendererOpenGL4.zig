const std = @import("std");
const c = @import("c");
const Cube = @import("../Cube.zig");
const xr_linear = @import("xr_linear.zig");

pub const api: xr_linear.GraphicsAPI = .OPENGL;

const VertexShaderGlsl: [*:0]const u8 =
    \\#version 410
    \\
    \\in vec3 VertexPos;
    \\in vec3 VertexColor;
    \\
    \\out vec3 PSVertexColor;
    \\
    \\uniform mat4 ModelViewProjection;
    \\
    \\void main() {
    \\   gl_Position = ModelViewProjection * vec4(VertexPos, 1.0);
    \\   PSVertexColor = VertexColor;
    \\}
    \\
;

const FragmentShaderGlsl: [*:0]const u8 =
    \\#version 410
    \\
    \\in vec3 PSVertexColor;
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\   FragColor = vec4(PSVertexColor, 1);
    \\}
    \\
;

allocator: std.mem.Allocator,
// var m_swapchainImageBuffers: std.ArrayList([]c.XrSwapchainImageOpenGLKHR) = .{};
swapchainFramebuffer: c.GLuint = 0,
program: c.GLuint = 0,
modelViewProjectionUniformLocation: c.GLint = 0,
vertexAttribCoords: c.GLuint = 0,
vertexAttribColor: c.GLuint = 0,
vao: c.GLuint = 0,
cubeVertexBuffer: c.GLuint = 0,
cubeIndexBuffer: c.GLuint = 0,

// Map color buffer to associated depth buffer. This map is populated on demand.
colorToDepthMap: std.AutoHashMap(u32, u32),

pub fn init(allocator: std.mem.Allocator) @This() {
    std.log.info("## RendererOpenGL4.init ##", .{});
    var this: @This() = .{
        .allocator = allocator,
        .colorToDepthMap = .init(allocator),
    };

    c.glGenFramebuffers(1, &this.swapchainFramebuffer);

    const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertexShader, 1, &VertexShaderGlsl, null);
    c.glCompileShader(vertexShader);
    checkShader(vertexShader);

    const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragmentShader, 1, &FragmentShaderGlsl, null);
    c.glCompileShader(fragmentShader);
    checkShader(fragmentShader);

    this.program = c.glCreateProgram();
    c.glAttachShader(this.program, vertexShader);
    c.glAttachShader(this.program, fragmentShader);
    c.glLinkProgram(this.program);
    checkProgram(this.program);

    c.glDeleteShader(vertexShader);
    c.glDeleteShader(fragmentShader);

    this.modelViewProjectionUniformLocation = c.glGetUniformLocation(this.program, "ModelViewProjection");

    this.vertexAttribCoords = @intCast(c.glGetAttribLocation(this.program, "VertexPos"));
    this.vertexAttribColor = @intCast(c.glGetAttribLocation(this.program, "VertexColor"));

    c.glGenBuffers(1, &this.cubeVertexBuffer);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, this.cubeVertexBuffer);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(@TypeOf(Cube.c_cubeVertices)),
        &Cube.c_cubeVertices,
        c.GL_STATIC_DRAW,
    );

    c.glGenBuffers(1, &this.cubeIndexBuffer);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, this.cubeIndexBuffer);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(@TypeOf(Cube.c_cubeIndices)),
        &Cube.c_cubeIndices,
        c.GL_STATIC_DRAW,
    );

    c.glGenVertexArrays(1, &this.vao);
    c.glBindVertexArray(this.vao);
    c.glEnableVertexAttribArray(this.vertexAttribCoords);
    c.glEnableVertexAttribArray(this.vertexAttribColor);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, this.cubeVertexBuffer);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, this.cubeIndexBuffer);
    c.glVertexAttribPointer(this.vertexAttribCoords, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Cube.Vertex), null);
    c.glVertexAttribPointer(this.vertexAttribColor, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Cube.Vertex), @ptrFromInt(@sizeOf(c.XrVector3f)));

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## RendererOpenGL4.deinit ##", .{});

    if (this.swapchainFramebuffer != 0) {
        c.glDeleteFramebuffers(1, &this.swapchainFramebuffer);
    }
    if (this.program != 0) {
        c.glDeleteProgram(this.program);
    }
    if (this.vao != 0) {
        c.glDeleteVertexArrays(1, &this.vao);
    }
    if (this.cubeVertexBuffer != 0) {
        c.glDeleteBuffers(1, &this.cubeVertexBuffer);
    }
    if (this.cubeIndexBuffer != 0) {
        c.glDeleteBuffers(1, &this.cubeIndexBuffer);
    }

    var it = this.colorToDepthMap.iterator();
    while (it.next()) |e| {
        c.glDeleteTextures(1, e.value_ptr);
    }
    this.colorToDepthMap.deinit();
}

fn checkShader(shader: c.GLuint) void {
    var r: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &r);
    if (r == c.GL_FALSE) {
        var msg: [4096]u8 = undefined;
        var length: c.GLsizei = undefined;
        c.glGetShaderInfoLog(shader, msg.len, &length, &msg);
        std.log.err("{s}", .{std.mem.sliceTo(&msg, 0)});
        @panic("Compile shader failed");
    }
}

fn checkProgram(prog: c.GLuint) void {
    var r: c.GLint = 0;
    c.glGetProgramiv(prog, c.GL_LINK_STATUS, &r);
    if (r == c.GL_FALSE) {
        var msg: [4096]u8 = undefined;
        var length: c.GLsizei = undefined;
        c.glGetProgramInfoLog(prog, msg.len, &length, &msg);
        std.log.err("{s}", .{std.mem.sliceTo(&msg, 0)});
        @panic("Link program failed");
    }
}

fn getDepthTexture(this: *@This(), colorTexture: u32) !u32 {
    // If a depth-stencil view has already been created for this back-buffer, use it.
    if (this.colorToDepthMap.get(colorTexture)) |depth| {
        return depth;
    }

    // This back-buffer has no corresponding depth-stencil texture, so create one with matching dimensions.

    c.glBindTexture(c.GL_TEXTURE_2D, colorTexture);
    var width: c.GLint = undefined;
    c.glGetTexLevelParameteriv(c.GL_TEXTURE_2D, 0, c.GL_TEXTURE_WIDTH, &width);
    var height: c.GLint = undefined;
    c.glGetTexLevelParameteriv(c.GL_TEXTURE_2D, 0, c.GL_TEXTURE_HEIGHT, &height);

    var depthTexture: u32 = undefined;
    c.glGenTextures(1, &depthTexture);
    c.glBindTexture(c.GL_TEXTURE_2D, depthTexture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_DEPTH_COMPONENT32,
        width,
        height,
        0,
        c.GL_DEPTH_COMPONENT,
        c.GL_FLOAT,
        null,
    );

    try this.colorToDepthMap.put(colorTexture, depthTexture);

    return depthTexture;
}

pub fn renderView(
    this: *@This(),
    layerView: *const c.XrCompositionLayerProjectionView,
    colorTexture: u32,
    swapchainFormat: i64,
    clear_color: [4]f32,
    vp: xr_linear.XrMatrix4x4f,
    cubes: []const Cube,
) !void {
    _ = swapchainFormat;
    std.debug.assert(layerView.subImage.imageArrayIndex == 0); // Texture arrays not supported.

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, this.swapchainFramebuffer);

    c.glViewport(
        layerView.subImage.imageRect.offset.x,
        layerView.subImage.imageRect.offset.y,
        layerView.subImage.imageRect.extent.width,
        layerView.subImage.imageRect.extent.height,
    );

    c.glFrontFace(c.GL_CW);
    c.glCullFace(c.GL_BACK);
    c.glEnable(c.GL_CULL_FACE);
    c.glEnable(c.GL_DEPTH_TEST);

    const depthTexture = try this.getDepthTexture(colorTexture);

    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, colorTexture, 0);
    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_TEXTURE_2D, depthTexture, 0);

    // Clear swapchain and depth buffer.
    c.glClearColor(clear_color[0], clear_color[1], clear_color[2], clear_color[3]);
    c.glClearDepth(1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

    // Set shaders and uniform variables.
    c.glUseProgram(this.program);

    // Set cube primitive data.
    c.glBindVertexArray(this.vao);

    // Render each cube
    for (cubes) |cube| {
        // Compute the model-view-projection transform and set it..
        const model = xr_linear.XrMatrix4x4f_CreateTranslationRotationScale(
            cube.Pose.position,
            cube.Pose.orientation,
            cube.Scale,
        );
        const mvp = xr_linear.XrMatrix4x4f_Multiply(vp, model);
        c.glUniformMatrix4fv(this.modelViewProjectionUniformLocation, 1, c.GL_FALSE, &mvp.m);

        // Draw the cube.
        c.glDrawElements(c.GL_TRIANGLES, Cube.c_cubeIndices.len, c.GL_UNSIGNED_SHORT, null);
    }

    c.glBindVertexArray(0);
    c.glUseProgram(0);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
}
