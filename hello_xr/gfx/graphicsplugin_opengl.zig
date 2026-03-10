const std = @import("std");
const c = @import("c");
const xrs = @import("../xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const geometry = @import("../geometry.zig");
const Options = @import("../Options.zig");
const gfxwrapper_opengl = @import("gfxwrapper_opengl_win32.zig");
const Cube = @import("../Cube.zig");
const xr_linear = @import("xr_linear.zig");

const extensions = [_][*:0]const u8{
    c.XR_KHR_OPENGL_ENABLE_EXTENSION_NAME,
};
pub fn GetInstanceExtensions() []const [*:0]const u8 {
    return &extensions;
}

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

var m_swapchainImageBuffers: std.ArrayList([]c.XrSwapchainImageOpenGLKHR) = .{};
var m_swapchainFramebuffer: c.GLuint = 0;
var m_program: c.GLuint = 0;
var m_modelViewProjectionUniformLocation: c.GLint = 0;
var m_vertexAttribCoords: c.GLuint = 0;
var m_vertexAttribColor: c.GLuint = 0;
var m_vao: c.GLuint = 0;
var m_cubeVertexBuffer: c.GLuint = 0;
var m_cubeIndexBuffer: c.GLuint = 0;

// Map color buffer to associated depth buffer. This map is populated on demand.
var m_colorToDepthMap: std.AutoHashMap(u32, u32) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    std.log.info("## OpenGL.init ##", .{});
    std.log.debug("GFX => OpenGL", .{});
    m_colorToDepthMap = .init(allocator);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    std.log.info("## OpenGL.deinit ##", .{});
    for (m_swapchainImageBuffers.items) |buf| {
        allocator.free(buf);
    }
    m_swapchainImageBuffers.deinit(allocator);

    //     if (m_swapchainFramebuffer != 0) {
    //         glDeleteFramebuffers(1, &m_swapchainFramebuffer);
    //     }
    //     if (m_program != 0) {
    //         glDeleteProgram(m_program);
    //     }
    //     if (m_vao != 0) {
    //         glDeleteVertexArrays(1, &m_vao);
    //     }
    //     if (m_cubeVertexBuffer != 0) {
    //         glDeleteBuffers(1, &m_cubeVertexBuffer);
    //     }
    //     if (m_cubeIndexBuffer != 0) {
    //         glDeleteBuffers(1, &m_cubeIndexBuffer);
    //     }

    var it = m_colorToDepthMap.iterator();
    while (it.next()) |e| {
        c.glDeleteTextures(1, e.value_ptr);
    }
    m_colorToDepthMap.deinit();

    //     gfxwrapper_opengl_deinit();
}

// // #if !defined(XR_USE_PLATFORM_MACOS)
// // void DebugMessageCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message) {
// //     (void)source;
// //     (void)type;
// //     (void)id;
// //     (void)severity;
// //     Log::Write(Log::Level::Info, "GL Debug: " + std::string(message, 0, length));
// // }
// // #endif  // !defined(XR_USE_PLATFORM_MACOS)

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

fn initializeResources() void {
    c.glGenFramebuffers(1, &m_swapchainFramebuffer);

    const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertexShader, 1, &VertexShaderGlsl, null);
    c.glCompileShader(vertexShader);
    checkShader(vertexShader);

    const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragmentShader, 1, &FragmentShaderGlsl, null);
    c.glCompileShader(fragmentShader);
    checkShader(fragmentShader);

    m_program = c.glCreateProgram();
    c.glAttachShader(m_program, vertexShader);
    c.glAttachShader(m_program, fragmentShader);
    c.glLinkProgram(m_program);
    checkProgram(m_program);

    c.glDeleteShader(vertexShader);
    c.glDeleteShader(fragmentShader);

    m_modelViewProjectionUniformLocation = c.glGetUniformLocation(m_program, "ModelViewProjection");

    m_vertexAttribCoords = @intCast(c.glGetAttribLocation(m_program, "VertexPos"));
    m_vertexAttribColor = @intCast(c.glGetAttribLocation(m_program, "VertexColor"));

    c.glGenBuffers(1, &m_cubeVertexBuffer);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, m_cubeVertexBuffer);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(@TypeOf(geometry.c_cubeVertices)),
        &geometry.c_cubeVertices,
        c.GL_STATIC_DRAW,
    );

    c.glGenBuffers(1, &m_cubeIndexBuffer);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, m_cubeIndexBuffer);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(@TypeOf(geometry.c_cubeIndices)),
        &geometry.c_cubeIndices,
        c.GL_STATIC_DRAW,
    );

    c.glGenVertexArrays(1, &m_vao);
    c.glBindVertexArray(m_vao);
    c.glEnableVertexAttribArray(m_vertexAttribCoords);
    c.glEnableVertexAttribArray(m_vertexAttribColor);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, m_cubeVertexBuffer);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, m_cubeIndexBuffer);
    c.glVertexAttribPointer(m_vertexAttribCoords, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(geometry.Vertex), null);
    c.glVertexAttribPointer(m_vertexAttribColor, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(geometry.Vertex), @ptrFromInt(@sizeOf(c.XrVector3f)));
}

pub fn InitializeDevice(instance: c.XrInstance, systemId: c.XrSystemId) XrError!void {
    // Extension function must be loaded by name
    var pfnGetOpenGLGraphicsRequirementsKHR: c.PFN_xrGetOpenGLGraphicsRequirementsKHR = undefined;
    _ = try XrResult.init(c.xrGetInstanceProcAddr(instance, "xrGetOpenGLGraphicsRequirementsKHR", &pfnGetOpenGLGraphicsRequirementsKHR));

    var graphicsRequirements: c.XrGraphicsRequirementsOpenGLKHR = .{ .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_OPENGL_KHR };
    _ = try XrResult.init((pfnGetOpenGLGraphicsRequirementsKHR.?)(instance, systemId, &graphicsRequirements));

    gfxwrapper_opengl.init();

    var major: c.GLint = 0;
    c.glGetIntegerv(c.GL_MAJOR_VERSION, &major);
    var minor: c.GLint = 0;
    c.glGetIntegerv(c.GL_MINOR_VERSION, &minor);

    const desiredApiVersion = c.XR_MAKE_VERSION(@as(i64, @intCast(major)), @as(i64, @intCast(minor)), 0);
    if (graphicsRequirements.minApiVersionSupported > desiredApiVersion) {
        @panic("Runtime does not support desired Graphics API and/or version");
    }

    initializeResources();
}

pub fn SelectColorSwapchainFormat(_: std.mem.Allocator, runtimeFormats: []i64) !i64 {
    // List of supported color swapchain formats.
    const SupportedColorSwapchainFormats = [_]i64{
        c.GL_RGB10_A2,
        c.GL_RGBA16F,
        // The two below should only be used as a fallback,
        // as they are linear color formats without enough bits for color
        // depth, thus leading to banding.
        c.GL_RGBA8,
        c.GL_RGBA8_SNORM,
    };

    for (runtimeFormats) |f| {
        for (SupportedColorSwapchainFormats) |s| {
            if (f == s) {
                return f;
            }
        }
    }

    @panic("No runtime swapchain format supported for color swapchain");
}

pub fn GetGraphicsBinding() *c.XrBaseInStructure {
    return @ptrCast(@alignCast(gfxwrapper_opengl.binding()));
}

pub fn AllocateSwapchainImageStructs(
    allocator: std.mem.Allocator,
    swapchainImageBase: []*c.XrSwapchainImageBaseHeader,
) !void {
    // Allocate and initialize the buffer of image structs
    // (must be sequential in memory for xrEnumerateSwapchainImages).
    // Return back an array of pointers to each swapchain image struct
    // so the consumer doesn't need to know the type/size.
    const swapchainImageBuffer = try allocator.alloc(c.XrSwapchainImageOpenGLKHR, swapchainImageBase.len);
    for (swapchainImageBuffer) |*buf| {
        buf.* = .{ .type = c.XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_KHR };
    }

    for (swapchainImageBuffer, 0..) |*buf, i| {
        swapchainImageBase[i] = @ptrCast(buf);
    }

    // Keep the buffer alive by moving it into the list of buffers.
    try m_swapchainImageBuffers.append(allocator, swapchainImageBuffer);
}

fn GetDepthTexture(colorTexture: u32) !u32 {
    // If a depth-stencil view has already been created for this back-buffer, use it.
    if (m_colorToDepthMap.get(colorTexture)) |depth| {
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

    try m_colorToDepthMap.put(colorTexture, depthTexture);

    return depthTexture;
}

pub fn renderView(
    layerView: *const c.XrCompositionLayerProjectionView,
    swapchainImage: *const c.XrSwapchainImageBaseHeader,
    swapchainFormat: i64,
    clear_color: [4]f32,
    cubes: []const Cube,
) !void {
    _ = swapchainFormat;
    std.debug.assert(layerView.subImage.imageArrayIndex == 0); // Texture arrays not supported.

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, m_swapchainFramebuffer);

    const colorTexture = @as(*const c.XrSwapchainImageOpenGLKHR, @ptrCast(swapchainImage)).image;

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

    const depthTexture = try GetDepthTexture(colorTexture);

    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, colorTexture, 0);
    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_TEXTURE_2D, depthTexture, 0);

    // Clear swapchain and depth buffer.
    c.glClearColor(clear_color[0], clear_color[1], clear_color[2], clear_color[3]);
    c.glClearDepth(1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

    // Set shaders and uniform variables.
    c.glUseProgram(m_program);

    const proj = xr_linear.XrMatrix4x4f_CreateProjectionFov(.OPENGL, layerView.fov, 0.05, 100.0);
    const toView = xr_linear.XrMatrix4x4f_CreateFromRigidTransform(layerView.pose);
    const view = xr_linear.XrMatrix4x4f_InvertRigidBody(toView);
    const vp = xr_linear.XrMatrix4x4f_Multiply(proj, view);

    // Set cube primitive data.
    c.glBindVertexArray(m_vao);

    // Render each cube
    for (cubes) |cube| {
        // Compute the model-view-projection transform and set it..
        const model = xr_linear.XrMatrix4x4f_CreateTranslationRotationScale(
            cube.Pose.position,
            cube.Pose.orientation,
            cube.Scale,
        );
        const mvp = xr_linear.XrMatrix4x4f_Multiply(vp, model);
        c.glUniformMatrix4fv(m_modelViewProjectionUniformLocation, 1, c.GL_FALSE, &mvp.m);

        // Draw the cube.
        c.glDrawElements(c.GL_TRIANGLES, geometry.c_cubeIndices.len, c.GL_UNSIGNED_SHORT, null);
    }

    c.glBindVertexArray(0);
    c.glUseProgram(0);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
}

pub fn GetSupportedSwapchainSampleCount(_: *const c.XrViewConfigurationView) u32 {
    return 1;
}

// void XR_GFX_UpdateOptions(const Options* options) { m_clearColor = options.GetBackgroundClearColor(); }
