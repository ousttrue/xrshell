const std = @import("std");
pub const c = @cImport({
    @cInclude("openxr/openxr.h");
    @cDefine("XR_USE_PLATFORM_EGL", "1");
    @cDefine("XR_USE_GRAPHICS_API_OPENGL_ES", "1");
    @cInclude("glad/gl.h");
    @cInclude("glad/egl.h");
    @cInclude("openxr/openxr_platform.h");
    @cInclude("linux/input.h");
});

// ================================
// Platform headers / declarations
// ================================
const OPENGL_VERSION_MAJOR = 4;
const OPENGL_VERSION_MINOR = 5;
// #define GLSL_VERSION "430"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 0  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer

// #define XR_USE_PLATFORM_WAYLAND 1

const wl = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-client-protocol.h");
    @cInclude("wayland-egl.h");
    // #include "EGL/eglplatform.h"
    @cInclude("glad/egl.h");
    @cInclude("linux/input.h");
    @cInclude("poll.h");
    @cInclude("unistd.h");
    // @cInclude("xdg-shell-unstable-v6.h");
});

// Initialize the gl extensions. Note we have to open a window.
var m_window: ksGpuWindow = .{};
var m_driverInstance: ksDriverInstance = .{};
var m_queueInfo: ksGpuQueueInfo = .{};
var m_colorFormat: ksGpuSurfaceColorFormat = .B8G8R8A8;
var m_depthFormat: ksGpuSurfaceDepthFormat = .D24;
var m_sampleCount: ksGpuSampleCount = ._1;
// https://github.com/WiVRn/WiVRn/issues/526
// https://projects.blender.org/blender/blender/issues/119901
// var m_graphicsBinding: c.XrGraphicsBindingOpenGLWaylandKHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WAYLAND_KHR };
var m_graphicsBinding: c.XrGraphicsBindingEGLMNDX = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_EGL_MNDX, .next = null };

// ================================
// Common defines
// ================================
// #define UNUSED_PARM(x) \
//     {                  \
//         (void)(x);     \
//     }
// #define ARRAY_SIZE(a) (sizeof((a)) / sizeof((a)[0]))
// #define OFFSETOF_MEMBER(type, member) (size_t)&((type*)0).member
// #define SIZEOF_MEMBER(type, member) sizeof(((type*)0).member)
fn BIT(T: type, x: usize) T {
    return (1 << (x));
}
// #ifndef MAX
// #define MAX(x, y) ((x > y) ? (x) : (y))
// #endif
// #ifndef MIN
// #define MIN(x, y) ((x < y) ? (x) : (y))
// #endif
// #define CLAMP(x, min, max) (((x) < (min)) ? (min) : (((x) > (max)) ? (max) : (x)))
// #define STRINGIFY_EXPANDED(a) #a
// #define STRINGIFY(a) STRINGIFY_EXPANDED(a)
//
// #define APPLICATION_NAME "OpenGL SI"
// #define WINDOW_TITLE "OpenGL SI"
//
// #define PROGRAM(name) name##GLSL
//
// #define GLSL_EXTENSIONS "#extension GL_EXT_shader_io_blocks : enable\n"
// #define GL_FINISH_SYNC 1

const ES_HIGHP = ""; // GLSL "430" disallows a precision qualifier on a image2D

// ================================================================================================================================
// Driver Instance.
// ================================================================================================================================

const ksDriverInstance = struct {
    placeholder: c_int = undefined,
};

// ================================================================================================================================
// GPU device.
// ================================================================================================================================

const ksGpuQueueProperty = enum(u32) {
    KS_GPU_QUEUE_PROPERTY_GRAPHICS = BIT(u32, 0),
    KS_GPU_QUEUE_PROPERTY_COMPUTE = BIT(u32, 1),
    KS_GPU_QUEUE_PROPERTY_TRANSFER = BIT(u32, 2),
};

const ksGpuQueuePriority = enum {
    LOW,
    MEDIUM,
    HIGH,
};

const MAX_QUEUES = 16;

const ksGpuQueueInfo = struct {
    queueCount: c_int = 0, // number of queues
    queueProperties: ksGpuQueueProperty = .KS_GPU_QUEUE_PROPERTY_COMPUTE, // desired queue family properties
    queuePriorities: [MAX_QUEUES]ksGpuQueuePriority = undefined, // individual queue priorities
};

const ksGpuDevice = struct {
    instance: *ksDriverInstance,
    queueInfo: ksGpuQueueInfo,
};

// ================================================================================================================================
//
// GPU context.
//
// A context encapsulates a queue that is used to submit command buffers.
// A context can only be used by a single thread.
// For optimal performance a context should only be created at load time, not at runtime.
//
// ================================================================================================================================

const ksGpuSurfaceColorFormat = enum {
    R5G6B5,
    B5G6R5,
    R8G8B8A8,
    B8G8R8A8,
    MAX,
};

const ksGpuSurfaceDepthFormat = enum {
    NONE,
    D16,
    D24,
    MAX,
};

const ksGpuSampleCount = enum(u8) {
    _1 = 1,
    _2 = 2,
    _4 = 4,
    _8 = 8,
    _16 = 16,
    _32 = 32,
    _64 = 64,
};

// typedef struct ksGpuLimits {
//     size_t maxPushConstantsSize;
//     int maxSamples;
// } ksGpuLimits;

const ksGpuContext = struct {
    device: *ksGpuDevice,
    native_window: wl.EGLNativeWindowType,
    display: wl.EGLDisplay,
    context: wl.EGLContext,
    config: wl.EGLConfig,
    mainSurface: wl.EGLSurface,
};

const ksGpuSurfaceBits = struct {
    redBits: u8,
    greenBits: u8,
    blueBits: u8,
    alphaBits: u8,
    colorBits: u8,
    depthBits: u8,
};

// ================================================================================================================================
//
// GPU Window.
//
// Window with associated GPU context for GPU accelerated rendering.
// For optimal performance a window should only be created at load time, not at runtime.
// Because on some platforms the OS/drivers use thread local storage, ksGpuWindow *must* be created
// and destroyed on the same thread that will actually render to the window and swap buffers.
//
// ================================================================================================================================

// typedef enum {
//     KS_GPU_WINDOW_EVENT_NONE,
//     KS_GPU_WINDOW_EVENT_ACTIVATED,
//     KS_GPU_WINDOW_EVENT_DEACTIVATED,
//     KS_GPU_WINDOW_EVENT_EXIT
// } ksGpuWindowEvent;

const ksGpuWindowInput = struct {
    keyInput: [256]bool,
    mouseInput: [8]bool,
    mouseInputX: [8]c_int,
    mouseInputY: [8]c_int,
};

pub const ksGpuWindow = struct {
    device: ksGpuDevice = undefined,
    context: ksGpuContext = undefined,
    colorFormat: ksGpuSurfaceColorFormat = undefined,
    depthFormat: ksGpuSurfaceDepthFormat = undefined,
    sampleCount: ksGpuSampleCount = undefined,
    windowWidth: c_int = undefined,
    windowHeight: c_int = undefined,
    windowSwapInterval: c_int = undefined,
    windowRefreshRate: f32 = undefined,
    windowFullscreen: bool = undefined,
    windowActive: bool = undefined,
    windowExit: bool = undefined,
    input: ksGpuWindowInput = undefined,

    // wayland
    display: ?*wl.wl_display = null,
    surface: ?*wl.wl_surface = null,
    registry: ?*wl.wl_registry = null,
    compositor: ?*wl.wl_compositor = null,
    // shell        struct zxdg_shell_v6* ;
    // shell_surface        struct zxdg_surface_v6* ;
    keyboard: ?*wl.wl_keyboard = null,
    pointer: ?*wl.wl_pointer = null,
    seat: ?*wl.wl_seat = null,
};

// ================================================================================================================================
// EGL error checking.
// ================================================================================================================================
fn EglErrorString(err: wl.EGLint) []const u8 {
    return switch (err) {
        wl.EGL_SUCCESS => "EGL_SUCCESS",
        wl.EGL_NOT_INITIALIZED => "EGL_NOT_INITIALIZED",
        wl.EGL_BAD_ACCESS => "EGL_BAD_ACCESS",
        wl.EGL_BAD_ALLOC => "EGL_BAD_ALLOC",
        wl.EGL_BAD_ATTRIBUTE => "EGL_BAD_ATTRIBUTE",
        wl.EGL_BAD_CONTEXT => "EGL_BAD_CONTEXT",
        wl.EGL_BAD_CONFIG => "EGL_BAD_CONFIG",
        wl.EGL_BAD_CURRENT_SURFACE => "EGL_BAD_CURRENT_SURFACE",
        wl.EGL_BAD_DISPLAY => "EGL_BAD_DISPLAY",
        wl.EGL_BAD_SURFACE => "EGL_BAD_SURFACE",
        wl.EGL_BAD_MATCH => "EGL_BAD_MATCH",
        wl.EGL_BAD_PARAMETER => "EGL_BAD_PARAMETER",
        wl.EGL_BAD_NATIVE_PIXMAP => "EGL_BAD_NATIVE_PIXMAP",
        wl.EGL_BAD_NATIVE_WINDOW => "EGL_BAD_NATIVE_WINDOW",
        wl.EGL_CONTEXT_LOST => "EGL_CONTEXT_LOST",
        else => "unknown",
    };
}

fn EGL(func: c_uint) void {
    if (func == wl.EGL_FALSE) {
        std.log.err(" failed: {s}", .{EglErrorString(wl.eglGetError())});
    }
}

// ================================================================================================================================
// Driver Instance.
// ================================================================================================================================
// bool ksDriverInstance_Create(ksDriverInstance* instance) {
//     memset(instance, 0, sizeof(ksDriverInstance));
//     return true;
// }

// void ksDriverInstance_Destroy(ksDriverInstance* instance) { memset(instance, 0, sizeof(ksDriverInstance)); }

// ================================================================================================================================
// GPU Device.
// ================================================================================================================================
fn ksGpuDevice_Create(device: *ksGpuDevice, instance: *ksDriverInstance, queueInfo: *const ksGpuQueueInfo) bool {
    //     /*
    //             Use an extensions to select the appropriate device:
    //             https://www.opengl.org/registry/specs/NV/gpu_affinity.txt
    //             https://www.opengl.org/registry/specs/AMD/wgl_gpu_association.txt
    //             https://www.opengl.org/registry/specs/AMD/glx_gpu_association.txt
    //
    //             On Linux configure each GPU to use a separate X screen and then select
    //             the X screen to render to.
    //     */

    device.* = .{
        .instance = instance,
        .queueInfo = queueInfo.*,
    };

    return true;
}

fn ksGpuDevice_Destroy(device: *ksGpuDevice) void {
    _ = device;
    // memset(device, 0, sizeof(ksGpuDevice));
}

// ================================================================================================================================
// GPU Context.
// ================================================================================================================================
fn ksGpuContext_BitsForSurfaceFormat(colorFormat: ksGpuSurfaceColorFormat, depthFormat: ksGpuSurfaceDepthFormat) ksGpuSurfaceBits {
    const bits: ksGpuSurfaceBits = .{
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
        //     bits.greenBits = ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
        //                           ? 8
        //                           : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
        //                                  ? 8
        //                                  : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
        //                                         ? 6
        //                                         : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? 6 : 8))));
        //     bits.blueBits = ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
        //                          ? 8
        //                          : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
        //                                 ? 8
        //                                 : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
        //                                        ? 5
        //                                        : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? 5 : 8))));
        //     bits.alphaBits = ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
        //                           ? 8
        //                           : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
        //                                  ? 8
        //                                  : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
        //                                         ? 0
        //                                         : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? 0 : 8))));
        //     bits.colorBits = bits.redBits + bits.greenBits + bits.blueBits + bits.alphaBits;
        .depthBits = (if (depthFormat == .D16) 16 else (if (depthFormat == .D24) 24 else 0)),
    };
    return bits;
}

// GLenum ksGpuContext_InternalSurfaceColorFormat(const ksGpuSurfaceColorFormat colorFormat) {
//     return ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
//                 ? GL_RGBA8
//                 : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
//                        ? GL_RGBA8
//                        : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
//                               ? GL_RGB565
//                               : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? GL_RGB565 : GL_RGBA8))));
// }

// GLenum ksGpuContext_InternalSurfaceDepthFormat(const ksGpuSurfaceDepthFormat depthFormat) {
//     return ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D16)
//                 ? GL_DEPTH_COMPONENT16
//                 : ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D24) ? GL_DEPTH_COMPONENT24 : GL_DEPTH_COMPONENT24));
// }

fn ksGpuContext_CreateForSurface(context: *ksGpuContext, device: *ksGpuDevice, native_display: ?*wl.wl_display) bool {
    context.device = device;

    if (wl.gladLoaderLoadEGL(null) == 0) {
        return false;
    }

    context.display = wl.eglGetDisplay(native_display);
    if (context.display == wl.EGL_NO_DISPLAY) {
        std.log.err("Could not create EGL Display.", .{});
        return false;
    }

    var majorVersion: wl.EGLint = undefined;
    var minorVersion: wl.EGLint = undefined;
    if (wl.eglInitialize(context.display, &majorVersion, &minorVersion) == 0) {
        std.log.err("eglInitialize failed.", .{});
        return false;
    }

    std.log.debug("Initialized EGL context version {}.{}\n", .{ majorVersion, minorVersion });
    if (wl.gladLoaderLoadEGL(context.display) == 0) {
        return false;
    }

    var numConfigs: wl.EGLint = undefined;
    var ret = wl.eglGetConfigs(context.display, null, 0, &numConfigs);
    if (ret != wl.EGL_TRUE or numConfigs == 0) {
        std.log.err("eglGetConfigs failed.", .{});
        return false;
    }

    // clang-format off
    const fbAttribs: []const wl.EGLint = &.{
        wl.EGL_SURFACE_TYPE,    wl.EGL_WINDOW_BIT,
        wl.EGL_RENDERABLE_TYPE, wl.EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
        wl.EGL_RED_SIZE,        8,
        wl.EGL_GREEN_SIZE,      8,
        wl.EGL_BLUE_SIZE,       8,
        wl.EGL_NONE,
    };
    ret = wl.eglChooseConfig(context.display, fbAttribs.ptr, &context.config, 1, &numConfigs);
    if (ret != wl.EGL_TRUE or numConfigs != 1) {
        std.log.err("eglChooseConfig failed.", .{});
        return false;
    }

    context.mainSurface = wl.eglCreateWindowSurface(context.display, context.config, context.native_window, null);
    if (context.mainSurface == wl.EGL_NO_SURFACE) {
        std.log.err("eglCreateWindowSurface failed", .{});
        return false;
    }

    _ = wl.eglBindAPI(wl.EGL_OPENGL_API);

    const contextAttribs: []const wl.EGLint = &.{
        wl.EGL_CONTEXT_OPENGL_PROFILE_MASK, wl.EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
        wl.EGL_CONTEXT_CLIENT_VERSION,      OPENGL_VERSION_MAJOR,
        wl.EGL_CONTEXT_MINOR_VERSION,       OPENGL_VERSION_MINOR,
        wl.EGL_NONE,
    };
    context.context = wl.eglCreateContext(context.display, context.config, wl.EGL_NO_CONTEXT, contextAttribs.ptr);
    if (context.context == wl.EGL_NO_CONTEXT) {
        std.log.err("Could not create OpenGL context.", .{});
        return false;
    }

    if (0 == wl.eglMakeCurrent(context.display, context.mainSurface, context.mainSurface, context.context)) {
        std.log.err("Could not make the current context current.", .{});
        return false;
    }

    return true;
}

// bool ksGpuContext_CreateShared(ksGpuContext* context, const ksGpuContext* other, int queueIndex) {
//     UNUSED_PARM(queueIndex);
//
//     memset(context, 0, sizeof(ksGpuContext));
//
//     context.device = other.device;
//
// #if defined(OS_WINDOWS)
//     context.hDC = other.hDC;
//     context.hGLRC = wglCreateContext(other.hDC);
//     if (!wglShareLists(other.hGLRC, context.hGLRC)) {
//         return false;
//     }
// #elif defined(OS_LINUX_XLIB) || defined(OS_LINUX_XCB_GLX)
//     context.xDisplay = other.xDisplay;
//     context.visualid = other.visualid;
//     context.glxFBConfig = other.glxFBConfig;
//     context.glxDrawable = other.glxDrawable;
//     context.glxContext = glXCreateNewContext(other.xDisplay, other.glxFBConfig, GLX_RGBA_TYPE, other.glxContext, True);
//     if (context.glxContext == null) {
//         return false;
//     }
// #elif defined(OS_LINUX_XCB)
//     context.connection = other.connection;
//     context.screen_number = other.screen_number;
//     context.fbconfigid = other.fbconfigid;
//     context.visualid = other.visualid;
//     context.glxDrawable = other.glxDrawable;
//     context.glxContext = xcb_generate_id(other.connection);
//     xcb_glx_create_context(other.connection, context.glxContext, other.visualid, other.screen_number, other.glxContext, 1);
//     context.glxContextTag = 0;
// #elif defined(OS_APPLE_MACOS)
//     context.nsContext = null;
//     CGLPixelFormatObj pf = CGLGetPixelFormat(other.cglContext);
//     if (CGLCreateContext(pf, other.cglContext, &context.cglContext) != kCGLNoError) {
//         Error("Failed : CGLCreateContext.");
//         return false;
//     }
//     CGSConnectionID cid;
//     CGSWindowID wid;
//     CGSSurfaceID sid;
//     if (CGLGetSurface(other.cglContext, &cid, &wid, &sid) != kCGLNoError) {
//         Error("Failed : CGLGetSurface.");
//         return false;
//     }
//     if (CGLSetSurface(context.cglContext, cid, wid, sid) != kCGLNoError) {
//         Error("Failed : CGLSetSurface.");
//         return false;
//     }
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     context.display = other.display;
//     EGLint configID;
//     if (!eglQueryContext(context.display, other.context, EGL_CONFIG_ID, &configID)) {
//         Error("eglQueryContext EGL_CONFIG_ID failed: %s", EglErrorString(eglGetError()));
//         return false;
//     }
//     enum { MAX_CONFIGS = 1024 };
//     EGLConfig configs[MAX_CONFIGS];
//     EGLint numConfigs = 0;
//     EGL(eglGetConfigs(context.display, configs, MAX_CONFIGS, &numConfigs));
//     context.config = 0;
//     for (int i = 0; i < numConfigs; i++) {
//         EGLint value = 0;
//         eglGetConfigAttrib(context.display, configs[i], EGL_CONFIG_ID, &value);
//         if (value == configID) {
//             context.config = configs[i];
//             break;
//         }
//     }
//     if (context.config == 0) {
//         Error("Failed to find share context config.");
//         return false;
//     }
//     EGLint surfaceType = 0;
//     eglGetConfigAttrib(context.display, context.config, EGL_SURFACE_TYPE, &surfaceType);
//
// #if defined(OS_ANDROID)
//     if ((surfaceType & EGL_PBUFFER_BIT) == 0) {
//         Error("Share context config does not have EGL_PBUFFER_BIT.");
//         return false;
//     }
// #endif
//     EGLint contextAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, OPENGL_VERSION_MAJOR, EGL_NONE};
//     context.context = eglCreateContext(context.display, context.config, other.context, contextAttribs);
//     if (context.context == EGL_NO_CONTEXT) {
//         Error("eglCreateContext() failed: %s", EglErrorString(eglGetError()));
//         return false;
//     }
// #if defined(OS_ANDROID)
//     const EGLint surfaceAttribs[] = {EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE};
//     context.tinySurface = eglCreatePbufferSurface(context.display, context.config, surfaceAttribs);
//     if (context.tinySurface == EGL_NO_SURFACE) {
//         Error("eglCreatePbufferSurface() failed: %s", EglErrorString(eglGetError()));
//         eglDestroyContext(context.display, context.context);
//         context.context = EGL_NO_CONTEXT;
//         return false;
//     }
//     context.mainSurface = context.tinySurface;
// #endif
// #endif
//     return true;
// }

fn ksGpuContext_Destroy(context: *ksGpuContext) void {
    // if (context.display != 0) {
    //     EGL(eglMakeCurrent(context.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT));
    // }
    // if (context.context != EGL_NO_CONTEXT) {
    //     EGL(eglDestroyContext(context.display, context.context));
    // }
    //
    // if (context.mainSurface != EGL_NO_SURFACE) {
    //     EGL(eglDestroySurface(context.display, context.mainSurface));
    // }
    context.display = null;
    context.config = null;
    context.mainSurface = wl.EGL_NO_SURFACE;
    context.context = wl.EGL_NO_CONTEXT;
}

fn ksGpuContext_SetCurrent(context: *ksGpuContext) void {
    EGL(wl.eglMakeCurrent(context.display, context.mainSurface, context.mainSurface, context.context));
}

fn ksGpuContext_UnsetCurrent(context: *ksGpuContext) void {
    EGL(wl.eglMakeCurrent(
        context.display,
        wl.EGL_NO_SURFACE,
        wl.EGL_NO_SURFACE,
        wl.EGL_NO_CONTEXT,
    ));
}

fn ksGpuContext_CheckCurrent(context: *ksGpuContext) bool {
    return (wl.eglGetCurrentContext() == context.context);
}

// ================================================================================================================================
//
// GPU Window.
//
// ================================================================================================================================

export fn _keyboard_keymap_cb(data: ?*anyopaque, keyboard: ?*wl.wl_keyboard, format: u32, fd: c_int, size: u32) void {
    _ = data;
    _ = keyboard;
    _ = format;
    _ = size;
    _ = std.c.close(fd);
}

export fn _keyboard_modifiers_cb(
    data: ?*anyopaque,
    keyboard: ?*wl.wl_keyboard,
    serial: u32,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    group: u32,
) void {
    _ = data;
    _ = keyboard;
    _ = serial;
    _ = mods_depressed;
    _ = mods_latched;
    _ = mods_locked;
    _ = group;
}

export fn _keyboard_enter_cb(
    data: ?*anyopaque,
    keyboard: ?*wl.wl_keyboard,
    serial: u32,
    surface: ?*wl.wl_surface,
    keys: ?*wl.wl_array,
) void {
    _ = data;
    _ = keyboard;
    _ = serial;
    _ = surface;
    _ = keys;
}

export fn _keyboard_leave_cb(
    data: ?*anyopaque,
    keyboard: ?*wl.wl_keyboard,
    serial: u32,
    surface: ?*wl.wl_surface,
) void {
    _ = data;
    _ = keyboard;
    _ = serial;
    _ = surface;
}

export fn _keyboard_key_cb(
    data: ?*anyopaque,
    keyboard: ?*wl.wl_keyboard,
    serial: u32,
    time: u32,
    key: u32,
    state: u32,
) void {
    _ = keyboard;
    _ = serial;
    _ = time;
    const window: *ksGpuWindow = @ptrCast(@alignCast(data));
    if (key == wl.KEY_ESC) window.windowExit = true;

    if (state != 0) window.input.keyInput[key] = true;
}

const keyboard_listener: wl.wl_keyboard_listener = .{
    .keymap = _keyboard_keymap_cb,
    .enter = _keyboard_enter_cb,
    .leave = _keyboard_leave_cb,
    .key = _keyboard_key_cb,
    .modifiers = _keyboard_modifiers_cb,
};

export fn _pointer_leave_cb(data: ?*anyopaque, pointer: ?*wl.wl_pointer, serial: u32, surface: ?*wl.wl_surface) void {
    _ = data;
    _ = pointer;
    _ = serial;
    _ = surface;
}

export fn _pointer_enter_cb(
    data: ?*anyopaque,
    pointer: ?*wl.wl_pointer,
    serial: u32,
    surface: ?*wl.wl_surface,
    sx: wl.wl_fixed_t,
    sy: wl.wl_fixed_t,
) void {
    _ = data;
    _ = surface;
    _ = sx;
    _ = sy;
    wl.wl_pointer_set_cursor(pointer, serial, null, 0, 0);
}

export fn _pointer_motion_cb(
    data: ?*anyopaque,
    pointer: ?*wl.wl_pointer,
    time: u32,
    x: wl.wl_fixed_t,
    y: wl.wl_fixed_t,
) void {
    _ = pointer;
    _ = time;
    const window: *ksGpuWindow = @ptrCast(@alignCast(data));
    window.input.mouseInputX[0] = wl.wl_fixed_to_int(x);
    window.input.mouseInputY[0] = wl.wl_fixed_to_int(y);
}

export fn _pointer_button_cb(
    data: ?*anyopaque,
    pointer: ?*wl.wl_pointer,
    serial: u32,
    time: u32,
    button: u32,
    state: u32,
) void {
    _ = pointer;
    _ = serial;
    _ = time;
    const window: *ksGpuWindow = @ptrCast(@alignCast(data));
    var button_id: usize = 0;
    switch (button) {
        wl.BTN_LEFT => {
            button_id = 0;
        },
        wl.BTN_MIDDLE => {
            button_id = 1;
        },
        wl.BTN_RIGHT => {
            button_id = 2;
        },
        else => {},
    }
    window.input.mouseInput[button_id] = state != 0;
}

export fn _pointer_axis_cb(data: ?*anyopaque, pointer: ?*wl.wl_pointer, time: u32, axis: u32, value: wl.wl_fixed_t) void {
    _ = data;
    _ = pointer;
    _ = time;
    _ = axis;
    _ = value;
}

const pointer_listener: wl.wl_pointer_listener = .{
    .enter = _pointer_enter_cb,
    .leave = _pointer_leave_cb,
    .motion = _pointer_motion_cb,
    .button = _pointer_button_cb,
    .axis = _pointer_axis_cb,
};

export fn _seat_capabilities_cb(data: ?*anyopaque, seat: ?*wl.wl_seat, caps: u32) void {
    const window: *ksGpuWindow = @ptrCast(@alignCast(data));
    if ((caps & wl.WL_SEAT_CAPABILITY_POINTER) != 0 and window.pointer == null) {
        window.pointer = wl.wl_seat_get_pointer(seat);
        _ = wl.wl_pointer_add_listener(window.pointer, &pointer_listener, window);
    } else if ((caps & wl.WL_SEAT_CAPABILITY_POINTER) == 0 and window.pointer != null) {
        wl.wl_pointer_destroy(window.pointer);
        window.pointer = null;
    }

    if ((caps & wl.WL_SEAT_CAPABILITY_KEYBOARD) != 0 and window.keyboard == null) {
        window.keyboard = wl.wl_seat_get_keyboard(seat);
        _ = wl.wl_keyboard_add_listener(window.keyboard, &keyboard_listener, window);
    } else if ((caps & wl.WL_SEAT_CAPABILITY_KEYBOARD) == 0 and window.keyboard != null) {
        wl.wl_keyboard_destroy(window.keyboard);
        window.keyboard = null;
    }
}

const seat_listener: wl.wl_seat_listener = .{
    .capabilities = _seat_capabilities_cb,
};

// static void _xdg_surface_configure_cb(void* data, struct zxdg_surface_v6* surface, uint32_t serial) {
//     zxdg_surface_v6_ack_configure(surface, serial);
// }

// const struct zxdg_surface_v6_listener xdg_surface_listener = {
//     _xdg_surface_configure_cb,
// };

// static void _xdg_shell_ping_cb(void* data, struct zxdg_shell_v6* shell, uint32_t serial) { zxdg_shell_v6_pong(shell, serial); }

// const struct zxdg_shell_v6_listener xdg_shell_listener = {
//     _xdg_shell_ping_cb,
// };

// static void _xdg_toplevel_configure_cb(void* data, struct zxdg_toplevel_v6* toplevel, int32_t width, int32_t height,
//                                        struct wl_array* states) {
//     ksGpuWindow* window = (ksGpuWindow*)data;
//
//     window.windowActive = false;
//
//     enum zxdg_toplevel_v6_state* state;
//     wl_array_for_each(state, states) {
//         switch (*state) {
//             case ZXDG_TOPLEVEL_V6_STATE_FULLSCREEN:
//                 break;
//             case ZXDG_TOPLEVEL_V6_STATE_RESIZING:
//                 window.windowWidth = width;
//                 window.windowWidth = height;
//                 break;
//             case ZXDG_TOPLEVEL_V6_STATE_MAXIMIZED:
//                 break;
//             case ZXDG_TOPLEVEL_V6_STATE_ACTIVATED:
//                 window.windowActive = true;
//                 break;
//         }
//     }
// }

// static void _xdg_toplevel_close_cb(void* data, struct zxdg_toplevel_v6* toplevel) {
//     ksGpuWindow* window = (ksGpuWindow*)data;
//     window.windowExit = true;
// }
//
// const struct zxdg_toplevel_v6_listener xdg_toplevel_listener = {
//     _xdg_toplevel_configure_cb,
//     _xdg_toplevel_close_cb,
// };

export fn _registry_cb(
    data: ?*anyopaque,
    registry: ?*wl.wl_registry,
    id: u32,
    interface: [*c]const u8,
    version: u32,
) void {
    _ = version;
    const window: *ksGpuWindow = @ptrCast(@alignCast(data));

    if (std.mem.eql(u8, std.mem.span(interface), "wl_compositor")) {
        window.compositor = @ptrCast(wl.wl_registry_bind(registry, id, &wl.wl_compositor_interface, 1));
    }
    // else if (std.mem.eql(interface, "zxdg_shell_v6")) {
    //     window.shell = wl_registry_bind(registry, id, &zxdg_shell_v6_interface, 1);
    //     zxdg_shell_v6_add_listener(window.shell, &xdg_shell_listener, null);
    // }
    else if (std.mem.eql(u8, std.mem.span(interface), "wl_seat")) {
        window.seat = @ptrCast(wl.wl_registry_bind(registry, id, &wl.wl_seat_interface, 1));
        _ = wl.wl_seat_add_listener(window.seat, &seat_listener, window);
    }
}

export fn _registry_remove_cb(data: ?*anyopaque, registry: ?*wl.wl_registry, id: u32) void {
    _ = data;
    _ = registry;
    _ = id;
}

const registry_listener: wl.wl_registry_listener = .{ .global = _registry_cb, .global_remove = _registry_remove_cb };

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
    _ = queueIndex;
    window.* = .{
        .surface = null,
        .registry = null,
        .compositor = null,
        // .shell = null,
        // .shell_surface = null,
        .keyboard = null,
        .pointer = null,
        .seat = null,
        .colorFormat = colorFormat,
        .depthFormat = depthFormat,
        .sampleCount = sampleCount,
        .windowWidth = width,
        .windowHeight = height,
        .windowSwapInterval = 1,
        .windowRefreshRate = 60.0,
        .windowFullscreen = fullscreen,
        .windowActive = false,
        .windowExit = false,
        .display = wl.wl_display_connect(null),
    };

    if (window.display == null) {
        std.log.err("Can't connect to wayland display.", .{});
        return false;
    }

    window.registry = wl.wl_display_get_registry(window.display);
    _ = wl.wl_registry_add_listener(window.registry, &registry_listener, window);

    _ = wl.wl_display_roundtrip(window.display);

    if (window.compositor == null) {
        std.log.err("Compositor protocol failed to bind", .{});
        return false;
    }

    // if (window.shell == null) {
    //     std.log.err("Compositor is missing support for zxdg_shell_v6.", .{});
    //     return false;
    // }

    window.surface = wl.wl_compositor_create_surface(window.compositor);
    if (window.surface == null) {
        std.log.err("Could not create compositor surface.", .{});
        return false;
    }

    // window.shell_surface = zxdg_shell_v6_get_xdg_surface(window.shell, window.surface);
    // if (window.shell_surface == null) {
    //     Error("Could not get shell surface.");
    //     return false;
    // }

    // zxdg_surface_v6_add_listener(window.shell_surface, &xdg_surface_listener, window);

    // struct zxdg_toplevel_v6* toplevel = zxdg_surface_v6_get_toplevel(window.shell_surface);
    // if (toplevel == null) {
    //     Error("Could not get surface toplevel.");
    //     return false;
    // }

    // zxdg_toplevel_v6_add_listener(toplevel, &xdg_toplevel_listener, window);
    //
    // zxdg_toplevel_v6_set_title(toplevel, WINDOW_TITLE);
    // zxdg_toplevel_v6_set_app_id(toplevel, APPLICATION_NAME);
    // zxdg_toplevel_v6_set_min_size(toplevel, width, height);
    // zxdg_toplevel_v6_set_max_size(toplevel, width, height);

    wl.wl_surface_commit(window.surface);

    window.context.native_window = wl.wl_egl_window_create(window.surface, width, height);

    if (window.context.native_window == null
        // wl.EGL_NO_SURFACE
    ) {
        ksGpuWindow_Destroy(window);
        std.log.err("Could not create wayland egl window.", .{});
        return false;
    }

    _ = ksGpuDevice_Create(&window.device, instance, queueInfo);

    _ = ksGpuContext_CreateForSurface(&window.context, &window.device, window.display);

    ksGpuContext_SetCurrent(&window.context);

    if (c.gladLoaderLoadGL() == 0) {
        std.log.err("gladLoaderLoadGL", .{});
    }

    return true;
}

fn ksGpuWindow_Destroy(window: *ksGpuWindow) void {
    if (window.pointer != null) wl.wl_pointer_destroy(window.pointer);
    if (window.keyboard != null) wl.wl_keyboard_destroy(window.keyboard);
    if (window.seat != null) wl.wl_seat_destroy(window.seat);

    wl.wl_egl_window_destroy(window.context.native_window);

    if (window.compositor != null) wl.wl_compositor_destroy(window.compositor);
    if (window.registry != null) wl.wl_registry_destroy(window.registry);
    // if (window.shell_surface != null) zxdg_surface_v6_destroy(window.shell_surface);
    // if (window.shell != null) zxdg_shell_v6_destroy(window.shell);
    if (window.surface != null) wl.wl_surface_destroy(window.surface);
    if (window.display != null) wl.wl_display_disconnect(window.display);

    ksGpuContext_Destroy(&window.context);
    ksGpuDevice_Destroy(&window.device);
}

// /*
//  * TODO:
//  * This is a work around for ksKeyboardKey naming collision
//  * with the definitions from <linux/input.h>.
//  * The proper fix for this is to rename the key enums.
//  */
//
// #undef KEY_A
// #undef KEY_B
// #undef KEY_C
// #undef KEY_D
// #undef KEY_E
// #undef KEY_F
// #undef KEY_G
// #undef KEY_H
// #undef KEY_I
// #undef KEY_J
// #undef KEY_K
// #undef KEY_L
// #undef KEY_M
// #undef KEY_N
// #undef KEY_O
// #undef KEY_P
// #undef KEY_Q
// #undef KEY_R
// #undef KEY_S
// #undef KEY_T
// #undef KEY_U
// #undef KEY_V
// #undef KEY_W
// #undef KEY_X
// #undef KEY_Y
// #undef KEY_Z
// #undef KEY_TAB
//
// typedef enum  // from <linux/input.h>
// { KEY_A = 30,
//   KEY_B = 48,
//   KEY_C = 46,
//   KEY_D = 32,
//   KEY_E = 18,
//   KEY_F = 33,
//   KEY_G = 34,
//   KEY_H = 35,
//   KEY_I = 23,
//   KEY_J = 36,
//   KEY_K = 37,
//   KEY_L = 38,
//   KEY_M = 50,
//   KEY_N = 49,
//   KEY_O = 24,
//   KEY_P = 25,
//   KEY_Q = 16,
//   KEY_R = 19,
//   KEY_S = 31,
//   KEY_T = 20,
//   KEY_U = 22,
//   KEY_V = 47,
//   KEY_W = 17,
//   KEY_X = 45,
//   KEY_Y = 21,
//   KEY_Z = 44,
//   KEY_TAB = 15,
//   KEY_RETURN = KEY_ENTER,
//   KEY_ESCAPE = KEY_ESC,
//   KEY_SHIFT_LEFT = KEY_LEFTSHIFT,
//   KEY_CTRL_LEFT = KEY_LEFTCTRL,
//   KEY_ALT_LEFT = KEY_LEFTALT,
//   KEY_CURSOR_UP = KEY_UP,
//   KEY_CURSOR_DOWN = KEY_DOWN,
//   KEY_CURSOR_LEFT = KEY_LEFT,
//   KEY_CURSOR_RIGHT = KEY_RIGHT } ksKeyboardKey;

const ksMouseButton = enum(c_int) { MOUSE_LEFT = c.BTN_LEFT, MOUSE_MIDDLE = c.BTN_MIDDLE, MOUSE_RIGHT = c.BTN_RIGHT };

pub fn init() void {
    m_window = .{};
    m_driverInstance = (ksDriverInstance){};
    m_queueInfo = (ksGpuQueueInfo){};
    m_colorFormat = .B8G8R8A8;
    m_depthFormat = .D24;
    m_sampleCount = ._1;
    if (!ksGpuWindow_Create(&m_window, &m_driverInstance, &m_queueInfo, 0, m_colorFormat, m_depthFormat, m_sampleCount, 640, 480, false)) {
        @panic("Unable to create GL context");
    }

    // TODO: Just need something other than null here for now (for validation).  Eventually need
    //       to correctly put in a valid pointer to an wl_display
    // m_graphicsBinding.display = @ptrFromInt(0xFFFFFFFF);
    // m_graphicsBinding.display = m_window.display;
    m_graphicsBinding.getProcAddress = @ptrCast(&eglGetProcAddress);
    m_graphicsBinding.display = m_window.context.display;
    m_graphicsBinding.config = m_window.context.config;
    m_graphicsBinding.context = m_window.context.context;
}

export fn eglGetProcAddress(name: [*c]const u8) c.PFN_xrEglGetProcAddressMNDX {
    return @ptrCast(c.eglGetProcAddress(name));
}

pub fn deinit() void {
    ksGpuWindow_Destroy(&m_window);
}

pub fn binding() *c.XrBaseInStructure {
    return @ptrCast(&m_graphicsBinding);
}
