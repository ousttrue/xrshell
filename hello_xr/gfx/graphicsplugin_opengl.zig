const std = @import("std");
pub const c = @import("../c.zig").openxr;
const xr_util = @import("../xr_util.zig");
const CHECK_XRCMD = xr_util.CHECK_XRCMD;
// #include "platform/xr_platform_include.h"
// #include "common.h"
const geometry = @import("../geometry.zig");
// #include "graphicsplugin.h"
// #include "options.h"
//
// #include <gfxwrapper_opengl.h>
// #include <common/xr_linear.h>
//
// #include <list>
// #include <vector>
// #include <map>
// #include <array>

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

// std::list<std::vector<XrSwapchainImageOpenGLKHR>> m_swapchainImageBuffers;
var m_swapchainFramebuffer: c.GLuint = 0;
var m_program: c.GLuint = 0;
var m_modelViewProjectionUniformLocation: c.GLint = 0;
var m_vertexAttribCoords: c.GLuint = 0;
var m_vertexAttribColor: c.GLuint = 0;
var m_vao: c.GLuint = 0;
var m_cubeVertexBuffer: c.GLuint = 0;
var m_cubeIndexBuffer: c.GLuint = 0;

// // Map color buffer to associated depth buffer. This map is populated on demand.
// std::map<uint32_t, uint32_t> m_colorToDepthMap;
// std::array<float, 4> m_clearColor;
//
// void XR_GFX_init(const Options* options) {
//     Log::Write(Log::Level::Info, "GFX => OpenGL");
//     m_clearColor = options->GetBackgroundClearColor();
// }
// // OpenGLGraphicsPlugin(const OpenGLGraphicsPlugin&) = delete;
// // OpenGLGraphicsPlugin& operator=(const OpenGLGraphicsPlugin&) = delete;
// // OpenGLGraphicsPlugin(OpenGLGraphicsPlugin&&) = delete;
// // OpenGLGraphicsPlugin& operator=(OpenGLGraphicsPlugin&&) = delete;
//
// void XR_GFX_deinit() {
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
//
//     for (auto& colorToDepth : m_colorToDepthMap) {
//         if (colorToDepth.second != 0) {
//             glDeleteTextures(1, &colorToDepth.second);
//         }
//     }
//
//     gfxwrapper_opengl_deinit();
// }

const extensions = [_][*:0]const u8{
    c.XR_KHR_OPENGL_ENABLE_EXTENSION_NAME,
};
pub fn GetInstanceExtensions() []const [*:0]const u8 {
    return &extensions;
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

fn CheckShader(shader: c.GLuint) void {
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

fn CheckProgram(prog: c.GLuint) void {
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

fn InitializeResources() void {
    c.glGenFramebuffers(1, &m_swapchainFramebuffer);

    const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertexShader, 1, &VertexShaderGlsl, null);
    c.glCompileShader(vertexShader);
    CheckShader(vertexShader);

    const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragmentShader, 1, &FragmentShaderGlsl, null);
    c.glCompileShader(fragmentShader);
    CheckShader(fragmentShader);

    m_program = c.glCreateProgram();
    c.glAttachShader(m_program, vertexShader);
    c.glAttachShader(m_program, fragmentShader);
    c.glLinkProgram(m_program);
    CheckProgram(m_program);

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
    c.glVertexAttribPointer(m_vertexAttribCoords, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(@TypeOf(geometry.Vertex)), null);
    c.glVertexAttribPointer(m_vertexAttribColor, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(@TypeOf(geometry.Vertex)), @ptrFromInt(@sizeOf(c.XrVector3f)));
}

pub fn InitializeDevice(instance: c.XrInstance, systemId: c.XrSystemId) void {
    // Extension function must be loaded by name
    var pfnGetOpenGLGraphicsRequirementsKHR: c.PFN_xrGetOpenGLGraphicsRequirementsKHR = undefined;
    CHECK_XRCMD(@src(), c.xrGetInstanceProcAddr(instance, "xrGetOpenGLGraphicsRequirementsKHR", &pfnGetOpenGLGraphicsRequirementsKHR));

    var graphicsRequirements: c.XrGraphicsRequirementsOpenGLKHR = .{ .type = c.XR_TYPE_GRAPHICS_REQUIREMENTS_OPENGL_KHR };
    CHECK_XRCMD(@src(), (pfnGetOpenGLGraphicsRequirementsKHR.?)(instance, systemId, &graphicsRequirements));

    c.gfxwrapper_opengl_init();

    var major: c.GLint = 0;
    c.glGetIntegerv(c.GL_MAJOR_VERSION, &major);
    var minor: c.GLint = 0;
    c.glGetIntegerv(c.GL_MINOR_VERSION, &minor);

    const desiredApiVersion = c.XR_MAKE_VERSION(@as(i64, @intCast(major)), @as(i64, @intCast(minor)), 0);
    if (graphicsRequirements.minApiVersionSupported > desiredApiVersion) {
        @panic("Runtime does not support desired Graphics API and/or version");
    }

    //     // #if !defined(XR_USE_PLATFORM_MACOS)
    //     //     glEnable(GL_DEBUG_OUTPUT);
    //     //     glDebugMessageCallback(
    //     //         [](GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void*
    //     //         userParam) {
    //     //             ((OpenGLGraphicsPlugin*)userParam)->DebugMessageCallback(source, type, id, severity, length, message);
    //     //         },
    //     //         this);
    //     // #endif  // !defined(XR_USE_PLATFORM_MACOS)

    InitializeResources();
}

// int64_t XR_GFX_SelectColorSwapchainFormat(const int64_t* runtimeFormats, size_t len) {
//     // List of supported color swapchain formats.
//     constexpr int64_t SupportedColorSwapchainFormats[] = {
//         GL_RGB10_A2,
//         GL_RGBA16F,
//         // The two below should only be used as a fallback, as they are linear color formats without enough bits for color
//         // depth, thus leading to banding.
//         GL_RGBA8,
//         GL_RGBA8_SNORM,
//     };
//
//     auto end = runtimeFormats + len;
//     auto swapchainFormatIt = std::find_first_of(runtimeFormats, end, std::begin(SupportedColorSwapchainFormats),
//                                                 std::end(SupportedColorSwapchainFormats));
//     if (swapchainFormatIt == end) {
//         THROW("No runtime swapchain format supported for color swapchain");
//     }
//
//     return *swapchainFormatIt;
// }

pub fn GetGraphicsBinding() *c.XrBaseInStructure {
    return @ptrCast(@alignCast(c.gfxwrapper_opengl_binding()));
}

// void XR_GFX_AllocateSwapchainImageStructs(uint32_t capacity, const XrSwapchainCreateInfo& /*swapchainCreateInfo*/,
//                                           XrSwapchainImageBaseHeader** swapchainImageBase) {
//     // Allocate and initialize the buffer of image structs (must be sequential in memory for xrEnumerateSwapchainImages).
//     // Return back an array of pointers to each swapchain image struct so the consumer doesn't need to know the type/size.
//     std::vector<XrSwapchainImageOpenGLKHR> swapchainImageBuffer(capacity, {XR_TYPE_SWAPCHAIN_IMAGE_OPENGL_KHR});
//     // std::vector<XrSwapchainImageBaseHeader*> swapchainImageBase;
//     for (size_t i = 0; i < capacity; ++i) {
//         swapchainImageBase[i] = reinterpret_cast<XrSwapchainImageBaseHeader*>(&swapchainImageBuffer[i]);
//     }
//
//     // Keep the buffer alive by moving it into the list of buffers.
//     m_swapchainImageBuffers.push_back(std::move(swapchainImageBuffer));
// }
//
// uint32_t GetDepthTexture(uint32_t colorTexture) {
//     // If a depth-stencil view has already been created for this back-buffer, use it.
//     auto depthBufferIt = m_colorToDepthMap.find(colorTexture);
//     if (depthBufferIt != m_colorToDepthMap.end()) {
//         return depthBufferIt->second;
//     }
//
//     // This back-buffer has no corresponding depth-stencil texture, so create one with matching dimensions.
//
//     GLint width;
//     GLint height;
//     glBindTexture(GL_TEXTURE_2D, colorTexture);
//     glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width);
//     glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height);
//
//     uint32_t depthTexture;
//     glGenTextures(1, &depthTexture);
//     glBindTexture(GL_TEXTURE_2D, depthTexture);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//     glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, width, height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, nullptr);
//
//     m_colorToDepthMap.insert(std::make_pair(colorTexture, depthTexture));
//
//     return depthTexture;
// }
//
// void XR_GFX_RenderView(const XrCompositionLayerProjectionView* layerView, const XrSwapchainImageBaseHeader* swapchainImage,
//                        int64_t swapchainFormat, const Cube* cubes, size_t cubeCount) {
//     CHECK(layerView->subImage.imageArrayIndex == 0);  // Texture arrays not supported.
//     // UNUSED_PARM(swapchainFormat);                    // Not used in this function for now.
//
//     glBindFramebuffer(GL_FRAMEBUFFER, m_swapchainFramebuffer);
//
//     const uint32_t colorTexture = reinterpret_cast<const XrSwapchainImageOpenGLKHR*>(swapchainImage)->image;
//
//     glViewport(static_cast<GLint>(layerView->subImage.imageRect.offset.x),
//                static_cast<GLint>(layerView->subImage.imageRect.offset.y),
//                static_cast<GLsizei>(layerView->subImage.imageRect.extent.width),
//                static_cast<GLsizei>(layerView->subImage.imageRect.extent.height));
//
//     glFrontFace(GL_CW);
//     glCullFace(GL_BACK);
//     glEnable(GL_CULL_FACE);
//     glEnable(GL_DEPTH_TEST);
//
//     const uint32_t depthTexture = GetDepthTexture(colorTexture);
//
//     glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);
//     glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthTexture, 0);
//
//     // Clear swapchain and depth buffer.
//     glClearColor(m_clearColor[0], m_clearColor[1], m_clearColor[2], m_clearColor[3]);
//     glClearDepth(1.0f);
//     glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
//
//     // Set shaders and uniform variables.
//     glUseProgram(m_program);
//
//     const auto& pose = layerView->pose;
//     XrMatrix4x4f proj;
//     XrMatrix4x4f_CreateProjectionFov(&proj, GRAPHICS_OPENGL, layerView->fov, 0.05f, 100.0f);
//     XrMatrix4x4f toView;
//     XrMatrix4x4f_CreateFromRigidTransform(&toView, &pose);
//     XrMatrix4x4f view;
//     XrMatrix4x4f_InvertRigidBody(&view, &toView);
//     XrMatrix4x4f vp;
//     XrMatrix4x4f_Multiply(&vp, &proj, &view);
//
//     // Set cube primitive data.
//     glBindVertexArray(m_vao);
//
//     // Render each cube
//     for (size_t i = 0; i < cubeCount; ++i) {
//         auto& cube = cubes[i];
//         // Compute the model-view-projection transform and set it..
//         XrMatrix4x4f model;
//         XrMatrix4x4f_CreateTranslationRotationScale(&model, &cube.Pose.position, &cube.Pose.orientation, &cube.Scale);
//         XrMatrix4x4f mvp;
//         XrMatrix4x4f_Multiply(&mvp, &vp, &model);
//         glUniformMatrix4fv(m_modelViewProjectionUniformLocation, 1, GL_FALSE, reinterpret_cast<const GLfloat*>(&mvp));
//
//         // Draw the cube.
//         glDrawElements(GL_TRIANGLES, static_cast<GLsizei>(ArraySize(Geometry::c_cubeIndices)), GL_UNSIGNED_SHORT, nullptr);
//     }
//
//     glBindVertexArray(0);
//     glUseProgram(0);
//     glBindFramebuffer(GL_FRAMEBUFFER, 0);
// }
//
// uint32_t XR_GFX_GetSupportedSwapchainSampleCount(const XrViewConfigurationView*) { return 1; }
//
// void XR_GFX_UpdateOptions(const Options* options) { m_clearColor = options->GetBackgroundClearColor(); }
