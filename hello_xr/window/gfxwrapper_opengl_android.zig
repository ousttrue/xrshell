const std = @import("std");
const c = @import("c");

const ksDriverInstance = struct {
    placeholder: c_int,
};

fn BIT(x: usize) c_int {
    return 1 << (x);
}

const ksGpuQueueProperty = enum(c_int) { GRAPHICS = BIT(0), COMPUTE = BIT(1), TRANSFER = BIT(2) };
const MAX_QUEUES = 16;
const ksGpuQueuePriority = enum { LOW, MEDIUM, HIGH };
const ksGpuQueueInfo = struct {
    queueCount: c_int, // number of queues
    queueProperties: ksGpuQueueProperty, // desired queue family properties
    queuePriorities: [MAX_QUEUES]ksGpuQueuePriority, // individual queue priorities
};

const ksGpuDevice = struct {
    instance: *ksDriverInstance,
    queueInfo: ksGpuQueueInfo,
};

const ksGpuContext = struct {
    device: *const ksGpuDevice,
    dpy: c.EGLDisplay,
    ctx: c.EGLContext,
};

const ksGpuSurfaceColorFormat = enum { R5G6B5, B5G6R5, R8G8B8A8, B8G8R8A8, MAX };

const ksGpuSurfaceDepthFormat = enum { NONE, D16, D24, MAX };

const ksGpuSampleCount = enum(u8) {
    _1 = 1,
    _2 = 2,
    _4 = 4,
    _8 = 8,
    _16 = 16,
    _32 = 32,
    _64 = 64,
};

const ksGpuWindowInput = struct {
    keyInput: [256]bool,
    mouseInput: [8]bool,
    mouseInputX: [8]c_int,
    mouseInputY: [8]c_int,
};

const ksGpuWindow = struct {
    device: ksGpuDevice,
    context: ksGpuContext,
    colorFormat: ksGpuSurfaceColorFormat,
    depthFormat: ksGpuSurfaceDepthFormat,
    sampleCount: ksGpuSampleCount,
    windowWidth: c_int,
    windowHeight: c_int,
    windowSwapInterval: c_int,
    windowRefreshRate: f32,
    windowFullscreen: bool,
    windowActive: bool,
    windowExit: bool,
    input: ksGpuWindowInput,

    // Java_t: c.java,
};

const ksGpuSurfaceBits = struct {
    redBits: u8,
    greenBits: u8,
    blueBits: u8,
    alphaBits: u8,
    colorBits: u8,
    depthBits: u8,
};

// Initialize the gl extensions. Note we have to open a window.
var m_window: ksGpuWindow = undefined;
var m_driverInstance: ksDriverInstance = undefined;
var m_queueInfo: ksGpuQueueInfo = undefined;
var m_colorFormat: ksGpuSurfaceColorFormat = .B8G8R8A8;
var m_depthFormat: ksGpuSurfaceDepthFormat = .D24;
var m_sampleCount: ksGpuSampleCount = ._1;
var m_graphicsBinding: c.XrGraphicsBindingOpenGLESAndroidKHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_ES_ANDROID_KHR, .next = null };

pub const extensions = [_][*:0]const u8{
    c.XR_KHR_OPENGL_ES_ENABLE_EXTENSION_NAME,
};

pub fn init() void {
    m_window = undefined;
    m_driverInstance = undefined;
    m_queueInfo = undefined;
    m_colorFormat = .B8G8R8A8;
    m_depthFormat = .D24;
    m_sampleCount = ._1;

    if (!ksGpuWindow_Create(&m_window, &m_driverInstance, &m_queueInfo, 0, m_colorFormat, m_depthFormat, m_sampleCount, 640, 480, false)) {
        @panic("Unable to create GL context");
    }

    m_graphicsBinding.display = m_window.context.dpy;
    m_graphicsBinding.config = null;
    m_graphicsBinding.context = m_window.context.ctx;
}

pub fn binding() *c.XrBaseInStructure {
    return @ptrCast(&m_graphicsBinding);
}

// ================================================================================================================================
// OpenGL extensions.
// ================================================================================================================================

// #if defined(OS_ANDROID)
//
// // GL_EXT_disjoint_timer_query without _EXT
// #if !defined(GL_TIMESTAMP)
// #define GL_QUERY_COUNTER_BITS GL_QUERY_COUNTER_BITS_EXT
// #define GL_TIME_ELAPSED GL_TIME_ELAPSED_EXT
// #define GL_TIMESTAMP GL_TIMESTAMP_EXT
// #define GL_GPU_DISJOINT GL_GPU_DISJOINT_EXT
// #endif
//
// // GL_EXT_buffer_storage without _EXT
// #if !defined(GL_BUFFER_STORAGE_FLAGS)
// #define GL_MAP_READ_BIT 0x0001                          // GL_MAP_READ_BIT_EXT
// #define GL_MAP_WRITE_BIT 0x0002                         // GL_MAP_WRITE_BIT_EXT
// #define GL_MAP_PERSISTENT_BIT 0x0040                    // GL_MAP_PERSISTENT_BIT_EXT
// #define GL_MAP_COHERENT_BIT 0x0080                      // GL_MAP_COHERENT_BIT_EXT
// #define GL_DYNAMIC_STORAGE_BIT 0x0100                   // GL_DYNAMIC_STORAGE_BIT_EXT
// #define GL_CLIENT_STORAGE_BIT 0x0200                    // GL_CLIENT_STORAGE_BIT_EXT
// #define GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT 0x00004000  // GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT_EXT
// #define GL_BUFFER_IMMUTABLE_STORAGE 0x821F              // GL_BUFFER_IMMUTABLE_STORAGE_EXT
// #define GL_BUFFER_STORAGE_FLAGS 0x8220                  // GL_BUFFER_STORAGE_FLAGS_EXT
// #endif
//
// #if !defined(EGL_OPENGL_ES3_BIT)
// #define EGL_OPENGL_ES3_BIT 0x0040
// #endif
//
// // GL_EXT_texture_cube_map_array
// #if !defined(GL_TEXTURE_CUBE_MAP_ARRAY)
// #define GL_TEXTURE_CUBE_MAP_ARRAY 0x9009
// #endif
//
// // GL_EXT_texture_filter_anisotropic
// #if !defined(GL_TEXTURE_MAX_ANISOTROPY_EXT)
// #define GL_TEXTURE_MAX_ANISOTROPY_EXT 0x84FE
// #define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT 0x84FF
// #endif
//
// // GL_EXT_texture_border_clamp or GL_OES_texture_border_clamp
// #if !defined(GL_CLAMP_TO_BORDER)
// #define GL_CLAMP_TO_BORDER 0x812D
// #endif
//
// // No 1D textures in OpenGL ES.
// #if !defined(GL_TEXTURE_1D)
// #define GL_TEXTURE_1D 0x0DE0
// #endif
//
// // No 1D texture arrays in OpenGL ES.
// #if !defined(GL_TEXTURE_1D_ARRAY)
// #define GL_TEXTURE_1D_ARRAY 0x8C18
// #endif
//
// // No multi-sampled texture arrays in OpenGL ES.
// #if !defined(GL_TEXTURE_2D_MULTISAMPLE_ARRAY)
// #define GL_TEXTURE_2D_MULTISAMPLE_ARRAY 0x9102
// #endif
//
// #endif

// ================================================================================================================================
// GPU Device.
// ================================================================================================================================
fn ksGpuDevice_Create(device: *ksGpuDevice, instance: *ksDriverInstance, queueInfo: *const ksGpuQueueInfo) bool {
    // Use an extensions to select the appropriate device:
    // https://www.opengl.org/registry/specs/NV/gpu_affinity.txt
    // https://www.opengl.org/registry/specs/AMD/wgl_gpu_association.txt
    // https://www.opengl.org/registry/specs/AMD/glx_gpu_association.txt
    //
    // On Linux configure each GPU to use a separate X screen and then select
    // the X screen to render to.

    //     memset(device, 0, sizeof(ksGpuDevice));

    device.* = .{
        .instance = instance,
        .queueInfo = queueInfo.*,
    };

    return true;
}

// void ksGpuDevice_Destroy(ksGpuDevice *device) { memset(device, 0, sizeof(ksGpuDevice)); }

// ================================================================================================================================
// GPU Context.
// ================================================================================================================================
fn ksGpuContext_BitsForSurfaceFormat(colorFormat: ksGpuSurfaceColorFormat, depthFormat: ksGpuSurfaceDepthFormat) ksGpuSurfaceBits {
    var bits: ksGpuSurfaceBits = .{
        .redBits = (if (colorFormat == .R8G8B8A8)
            8
        else
            (if (colorFormat == .B8G8R8A8)
                8
            else
                (if (colorFormat == .R5G6B5)
                    5
                else
                    (if (colorFormat == .B5G6R5) 5 else 8)))),
        .greenBits = (if (colorFormat == .R8G8B8A8)
            8
        else
            (if (colorFormat == .B8G8R8A8)
                8
            else
                (if (colorFormat == .R5G6B5)
                    6
                else
                    (if (colorFormat == .B5G6R5) 6 else 8)))),
        .blueBits = (if (colorFormat == .R8G8B8A8)
            8
        else
            (if (colorFormat == .B8G8R8A8)
                8
            else
                (if (colorFormat == .R5G6B5)
                    5
                else
                    (if (colorFormat == .B5G6R5) 5 else 8)))),
        .alphaBits = (if (colorFormat == .R8G8B8A8)
            8
        else
            (if (colorFormat == .B8G8R8A8)
                8
            else
                (if (colorFormat == .R5G6B5)
                    0
                else
                    (if (colorFormat == .B5G6R5) 0 else 8)))),
        .depthBits = (if (depthFormat == .D16) 16 else (if (depthFormat == .D24) 24 else 0)),
        .colorBits = 0,
    };
    bits.colorBits = bits.redBits + bits.greenBits + bits.blueBits + bits.alphaBits;
    return bits;
}

fn EglErrorString(err: c.EGLint) []const u8 {
    return switch (err) {
        c.EGL_SUCCESS => "EGL_SUCCESS",
        c.EGL_NOT_INITIALIZED => "EGL_NOT_INITIALIZED",
        c.EGL_BAD_ACCESS => "EGL_BAD_ACCESS",
        c.EGL_BAD_ALLOC => "EGL_BAD_ALLOC",
        c.EGL_BAD_ATTRIBUTE => "EGL_BAD_ATTRIBUTE",
        c.EGL_BAD_CONTEXT => "EGL_BAD_CONTEXT",
        c.EGL_BAD_CONFIG => "EGL_BAD_CONFIG",
        c.EGL_BAD_CURRENT_SURFACE => "EGL_BAD_CURRENT_SURFACE",
        c.EGL_BAD_DISPLAY => "EGL_BAD_DISPLAY",
        c.EGL_BAD_SURFACE => "EGL_BAD_SURFACE",
        c.EGL_BAD_MATCH => "EGL_BAD_MATCH",
        c.EGL_BAD_PARAMETER => "EGL_BAD_PARAMETER",
        c.EGL_BAD_NATIVE_PIXMAP => "EGL_BAD_NATIVE_PIXMAP",
        c.EGL_BAD_NATIVE_WINDOW => "EGL_BAD_NATIVE_WINDOW",
        c.EGL_CONTEXT_LOST => "EGL_CONTEXT_LOST",
        else => "unknown",
    };
}

fn EGL(func: c_uint) void {
    if (func == c.EGL_FALSE) {
        std.log.err(" failed: {s}", .{EglErrorString(c.eglGetError())});
    }
}

// void ksGpuContext_Destroy(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     if (context.ctx != EGL_NO_CONTEXT) {
//         EGL(eglDestroyContext(context.dpy, context.ctx));
//     }
//
//     if (context.dpy != EGL_NO_DISPLAY) {
//         EGL(eglTerminate(context.dpy));
//     }
//
//     context.dpy = EGL_NO_DISPLAY;
//     context.ctx = EGL_NO_CONTEXT;
//
// }

fn ksGpuContext_SetCurrent(context: *ksGpuContext) void {
    EGL(c.eglMakeCurrent(context.dpy, c.EGL_NO_SURFACE, c.EGL_NO_SURFACE, context.ctx));
}

// void ksGpuContext_UnsetCurrent(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     EGL(eglMakeCurrent(context.dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT));
// }

// bool ksGpuContext_CheckCurrent(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     return (eglGetCurrentContext() == context.ctx);
// #else

// ================================================================================================================================
// GPU Window.
// ================================================================================================================================

// #elif defined(OS_ANDROID)
//
// void ksGpuWindow_Destroy(ksGpuWindow *window) {
//     ksGpuContext_Destroy(&window.context);
//     ksGpuDevice_Destroy(&window.device);
// }

fn ksGpuWindow_Create(
    window: *ksGpuWindow,
    instance: *ksDriverInstance,
    queueInfo: *const ksGpuQueueInfo,
    queueIndex: c_int,
    colorFormat: ksGpuSurfaceColorFormat,
    depthFormat: ksGpuSurfaceDepthFormat,
    sampleCount: ksGpuSampleCount,
    width: c_int,
    height: c_int,
    fullscreen: bool,
) bool {
    return ksGpuWindow_CreateEGL(window, instance, queueInfo, queueIndex, colorFormat, depthFormat, sampleCount, width, height, fullscreen);
}

const OPENGLES_VERSION_MAJOR = 3;

fn ksGpuContext_CreateForSurfaceEGL(
    context: *ksGpuContext,
    device: *const ksGpuDevice,
    queueIndex: c_int,
    colorFormat: ksGpuSurfaceColorFormat,
    depthFormat: ksGpuSurfaceDepthFormat,
    sampleCount: ksGpuSampleCount,
    dpy: c.EGLDisplay,
) bool {
    _ = sampleCount;
    context.device = device;
    context.dpy = dpy;

    // clang-format off
    var glesContextAttribs = [_]c.EGLint{
        c.EGL_CONTEXT_CLIENT_VERSION,     OPENGLES_VERSION_MAJOR,
        c.EGL_CONTEXT_PRIORITY_LEVEL_IMG, c.EGL_CONTEXT_PRIORITY_MEDIUM_IMG,
        c.EGL_NONE,
    };
    // clang-format on
    // Use the default priority if KS_GPU_QUEUE_PRIORITY_MEDIUM is selected.
    const priority = device.queueInfo.queuePriorities[@intCast(queueIndex)];
    if (priority != .MEDIUM) {
        glesContextAttribs[3] = if (priority == .LOW) c.EGL_CONTEXT_PRIORITY_LOW_IMG else c.EGL_CONTEXT_PRIORITY_HIGH_IMG;
    }

    const bits: ksGpuSurfaceBits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);

    const configAttribs = [_]c.EGLint{
        c.EGL_SURFACE_TYPE,    c.EGL_WINDOW_BIT,
        c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES3_BIT,
        c.EGL_RED_SIZE,        bits.redBits,
        c.EGL_GREEN_SIZE,      bits.greenBits,
        c.EGL_BLUE_SIZE,       bits.blueBits,
        c.EGL_ALPHA_SIZE,      bits.alphaBits,
        c.EGL_NONE,
    };

    var config: c.EGLConfig = undefined;
    var numConfigs: c.EGLint = undefined;
    EGL(c.eglChooseConfig(context.dpy, &configAttribs, &config, 1, &numConfigs));

    context.ctx = c.eglCreateContext(context.dpy, config, c.EGL_NO_CONTEXT, &glesContextAttribs);
    if (context.ctx == c.EGL_NO_CONTEXT) {
        std.log.err("eglCreateContext() failed: {s}", .{EglErrorString(c.eglGetError())});
        return false;
    }

    EGL(c.eglBindAPI(c.EGL_OPENGL_ES_API));

    return true;
}

fn ksGpuWindow_CreateEGL(
    window: *ksGpuWindow,
    instance: *ksDriverInstance,
    queueInfo: *const ksGpuQueueInfo,
    queueIndex: c_int,
    colorFormat: ksGpuSurfaceColorFormat,
    depthFormat: ksGpuSurfaceDepthFormat,
    sampleCount: ksGpuSampleCount,
    width: c_int,
    height: c_int,
    fullscreen: bool,
) bool {
    _ = fullscreen;

    window.* = .{
        .colorFormat = colorFormat,
        .depthFormat = depthFormat,
        .sampleCount = sampleCount,
        .windowWidth = width,
        .windowHeight = height,
        .windowSwapInterval = 1,
        .windowRefreshRate = 60.0,
        .windowFullscreen = true,
        .windowActive = false,
        .windowExit = false,
        //
        .device = undefined,
        .context = undefined,
        .input = undefined,
    };

    // {
    //     const eglVersion = c.gladLoaderLoadEGL(c.EGL_DEFAULT_DISPLAY);
    //     if (0 == eglVersion) {
    //         std.log.err("Failed to load EGL", .{});
    //         return false;
    //     }
    //
    //     std.log.info("Loaded EGL {}.{} on first load", .{ c.GLAD_VERSION_MAJOR(eglVersion), c.GLAD_VERSION_MINOR(eglVersion) });
    // }

    const dpy = c.eglGetDisplay(c.EGL_DEFAULT_DISPLAY);
    EGL(c.eglInitialize(dpy, null, null));

    // need second load now that EGL is initialized - bootstrapping problem
    // {
    //     const eglVersion = c.gladLoaderLoadEGL(dpy);
    //     if (0 == eglVersion) {
    //         std.log.err("Failed to reload EGL", .{});
    //         return false;
    //     }
    //
    //     std.log.info("Loaded EGL {}.{} after reload.", .{ c.GLAD_VERSION_MAJOR(eglVersion), c.GLAD_VERSION_MINOR(eglVersion) });
    // }

    _ = ksGpuDevice_Create(&window.device, instance, queueInfo);
    _ = ksGpuContext_CreateForSurfaceEGL(&window.context, &window.device, queueIndex, colorFormat, depthFormat, sampleCount, dpy);

    ksGpuContext_SetCurrent(&window.context);

    // _ = c.gladLoaderLoadGLES2();

    return true;
}
