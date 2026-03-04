const std = @import("std");
const c = @import("c");

// ================================
// Platform headers / declarations
// ================================
const OPENGL_VERSION_MAJOR = 4;
const OPENGL_VERSION_MINOR = 3;
// #define GLSL_VERSION "430"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 0  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer
// #define GRAPHICS_API_OPENGL 1
// #define OUTPUT_PATH ""

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
fn BIT(x: usize) u32 {
    return 1 << x;
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

const APPLICATION_NAME = "OpenGL SI";
const WINDOW_TITLE = "OpenGL SI";

// #define PROGRAM(name) name##GLSL
//
// #define GLSL_EXTENSIONS "#extension GL_EXT_shader_io_blocks : enable\n"
// #define GL_FINISH_SYNC 1
//
// #if defined(OS_ANDROID)
// #define ES_HIGHP "highp"  // GLSL "310 es" requires a precision qualifier on a image2D
// #else
// #define ES_HIGHP ""  // GLSL "430" disallows a precision qualifier on a image2D
// #endif

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
    GRAPHICS = BIT(0),
    COMPUTE = BIT(1),
    TRANSFER = BIT(2),
};

const ksGpuQueuePriority = enum {
    LOW,
    MEDIUM,
    HIGH,
};

const MAX_QUEUES = 16;

const ksGpuQueueInfo = struct {
    // number of queues
    queueCount: c_int = undefined,
    // desired queue family properties
    queueProperties: ksGpuQueueProperty = undefined,
    // individual queue priorities
    queuePriorities: [MAX_QUEUES]ksGpuQueuePriority = undefined,
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
// ================================================================================================================================

const ksGpuSurfaceColorFormat = enum { R5G6B5, B5G6R5, R8G8B8A8, B8G8R8A8, MAX };

const ksGpuSurfaceDepthFormat = enum { NONE, D16, D24, MAX };

const ksGpuSampleCount = enum(c_int) {
    _1 = 1,
    _2 = 2,
    _4 = 4,
    _8 = 8,
    _16 = 16,
    _32 = 32,
    _64 = 64,
};

const ksGpuLimits = struct {
    maxPushConstantsSize: usize,
    maxSamples: c_int,
};

const ksGpuContext = struct {
    device: *const ksGpuDevice,
    hDC: c.HDC,
    hGLRC: c.HGLRC,
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
// GPU Window.
//
// Window with associated GPU context for GPU accelerated rendering.
// For optimal performance a window should only be created at load time, not at runtime.
// Because on some platforms the OS/drivers use thread local storage, ksGpuWindow *must* be created
// and destroyed on the same thread that will actually render to the window and swap buffers.
// ================================================================================================================================

const ksGpuWindowEvent = enum { NONE, ACTIVATED, DEACTIVATED, EXIT };

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

    hInstance: c.HINSTANCE,
    hDC: c.HDC,
    hWnd: c.HWND,
    windowActiveState: bool,
};

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
    device.* = .{
        .instance = instance,
        .queueInfo = queueInfo.*,
    };
    return true;
}

fn ksGpuDevice_Destroy(device: *ksGpuDevice) void {
    device.* = .{
        .instance = undefined,
        .queueInfo = undefined,
    };
}

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

// GLenum ksGpuContext_InternalSurfaceColorFormat(const ksGpuSurfaceColorFormat colorFormat) {
//     return ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
//                 ? GL_RGBA8
//                 : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
//                        ? GL_RGBA8
//                        : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
//                               ? GL_RGB565
//                               : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? GL_RGB565 : GL_RGBA8))));
// }
//
// GLenum ksGpuContext_InternalSurfaceDepthFormat(const ksGpuSurfaceDepthFormat depthFormat) {
//     return ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D16)
//                 ? GL_DEPTH_COMPONENT16
//                 : ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D24) ? GL_DEPTH_COMPONENT24 : GL_DEPTH_COMPONENT24));

fn ksGpuContext_CreateForSurface(
    context: *ksGpuContext,
    device: *const ksGpuDevice,
    queueIndex: c_int,
    colorFormat: ksGpuSurfaceColorFormat,
    depthFormat: ksGpuSurfaceDepthFormat,
    sampleCount: ksGpuSampleCount,
    hInstance: c.HINSTANCE,
    hDC: c.HDC,
) bool {
    _ = queueIndex;

    context.device = device;

    const bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);

    var pfd: c.PIXELFORMATDESCRIPTOR = .{
        .nSize = @sizeOf(c.PIXELFORMATDESCRIPTOR),
        .nVersion = 1, // version
        .dwFlags = c.PFD_DRAW_TO_WINDOW | // must support windowed
            c.PFD_SUPPORT_OPENGL | // must support OpenGL
            c.PFD_DOUBLEBUFFER, // must support double buffering
        .iPixelType = c.PFD_TYPE_RGBA,
        .cColorBits = bits.colorBits,
        .cRedBits = 0,
        .cRedShift = 0,
        .cGreenBits = 0,
        .cGreenShift = 0,
        .cBlueBits = 0,
        .cBlueShift = 0,
        .cAlphaBits = 0,
        .cAlphaShift = 0,
        .cAccumBits = 0,
        .cAccumRedBits = 0,
        .cAccumGreenBits = 0,
        .cAccumBlueBits = 0,
        .cAccumAlphaBits = 0,
        .cDepthBits = bits.depthBits,
        .cStencilBits = 0,
        .cAuxBuffers = 0,
        .iLayerType = c.PFD_MAIN_PLANE,
        .bReserved = 0,
        .dwLayerMask = 0,
        .dwVisibleMask = 0,
        .dwDamageMask = 0,
    };

    var localWnd: c.HWND = null;
    var localDC = hDC;

    if (@intFromEnum(sampleCount) > @intFromEnum(ksGpuSampleCount._1)) {
        // A valid OpenGL context is needed to get OpenGL extensions including wglChoosePixelFormatARB
        // and wglCreateContextAttribsARB. A device context with a valid pixel format is needed to create
        // an OpenGL context. However, once a pixel format is set on a device context it is final.
        // Therefore a pixel format is set on the device context of a temporary window to create a context
        // to get the extensions for multi-sampling.
        localWnd = c.CreateWindowA(APPLICATION_NAME, "temp", 0, 0, 0, 0, 0, null, null, hInstance, null);
        localDC = c.GetDC(localWnd);
    }

    const pixelFormat = c.ChoosePixelFormat(localDC, &pfd);
    if (pixelFormat == 0) {
        std.log.err("Failed to find a suitable pixel format.", .{});
        return false;
    }

    if (0 == c.SetPixelFormat(localDC, pixelFormat, &pfd)) {
        std.log.err("Failed to set the pixel format.", .{});
        return false;
    }

    // Now that the pixel format is set, create a temporary context to get the extensions.
    {
        _ = c.gladLoaderLoadWGL(localDC);
        const hGLRC = c.wglCreateContext(localDC);
        _ = c.wglMakeCurrent(localDC, hGLRC);

        _ = c.gladLoaderLoadWGL(localDC);

        _ = c.wglMakeCurrent(null, null);
        _ = c.wglDeleteContext(hGLRC);
    }

    if (@intFromEnum(sampleCount) > @intFromEnum(ksGpuSampleCount._1)) {
        // Release the device context and destroy the window that were created to get extensions.
        _ = c.ReleaseDC(localWnd, localDC);
        _ = c.DestroyWindow(localWnd);

        const pixelFormatAttribs = [_]c_int{
            c.WGL_DRAW_TO_WINDOW_ARB,
            c.GL_TRUE,
            c.WGL_SUPPORT_OPENGL_ARB,
            c.GL_TRUE,
            c.WGL_DOUBLE_BUFFER_ARB,
            c.GL_TRUE,
            c.WGL_PIXEL_TYPE_ARB,
            c.WGL_TYPE_RGBA_ARB,
            c.WGL_COLOR_BITS_ARB,
            bits.colorBits,
            c.WGL_DEPTH_BITS_ARB,
            bits.depthBits,
            c.WGL_SAMPLE_BUFFERS_ARB,
            1,
            c.WGL_SAMPLES_ARB,
            @intFromEnum(sampleCount),
            0,
        };

        var numPixelFormats: u32 = 0;

        if (0 == c.wglChoosePixelFormatARB(hDC, &pixelFormatAttribs, null, 1, pixelFormat, &numPixelFormats) or numPixelFormats == 0) {
            std.log.err("Failed to find MSAA pixel format.", .{});
            return false;
        }

        _ = c.memset(&pfd, 0, @sizeOf(@TypeOf(pfd)));

        if (0 == c.DescribePixelFormat(hDC, pixelFormat, @sizeOf(c.PIXELFORMATDESCRIPTOR), &pfd)) {
            std.log.err("Failed to describe the pixel format.", .{});
            return false;
        }

        if (0 == c.SetPixelFormat(hDC, pixelFormat, &pfd)) {
            std.log.err("Failed to set the pixel format.", .{});
            return false;
        }
    }

    const contextAttribs = [_]c_int{
        c.WGL_CONTEXT_MAJOR_VERSION_ARB,
        OPENGL_VERSION_MAJOR,
        c.WGL_CONTEXT_MINOR_VERSION_ARB,
        OPENGL_VERSION_MINOR,
        c.WGL_CONTEXT_PROFILE_MASK_ARB,
        c.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        c.WGL_CONTEXT_FLAGS_ARB,
        c.WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB | c.WGL_CONTEXT_DEBUG_BIT_ARB,
        0,
    };

    context.hDC = hDC;
    context.hGLRC = c.wglCreateContextAttribsARB(hDC, null, &contextAttribs);
    if (null == context.hGLRC) {
        std.log.err("Failed to create GL context.", .{});
        return false;
    }

    _ = c.wglMakeCurrent(hDC, context.hGLRC);

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
    if (context.hGLRC != null) {
        if (0 == c.wglMakeCurrent(null, null)) {
            const err = c.GetLastError();
            std.log.err("Failed to release context error code ({}).", .{err});
        }

        if (0 == c.wglDeleteContext(context.hGLRC)) {
            const err = c.GetLastError();
            std.log.err("Failed to delete context error code ({}).", .{err});
        }
        context.hGLRC = null;
    }
    context.hDC = null;
}

fn ksGpuContext_SetCurrent(context: *ksGpuContext) void {
    _ = c.wglMakeCurrent(context.hDC, context.hGLRC);
}

// void ksGpuContext_UnsetCurrent(ksGpuContext* context) {
// #if defined(OS_WINDOWS)
//     wglMakeCurrent(context.hDC, null);
// #elif defined(OS_LINUX_XLIB) || defined(OS_LINUX_XCB_GLX)
//     glXMakeCurrent(context.xDisplay, /* None */ 0L, null);
// #elif defined(OS_LINUX_XCB)
//     xcb_glx_make_current(context.connection, 0, 0, 0);
// #elif defined(OS_APPLE_MACOS)
//     (void)context;
//     CGLSetCurrentContext(null);
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     EGL(eglMakeCurrent(context.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT));
// #endif
// }
//
// bool ksGpuContext_CheckCurrent(ksGpuContext* context) {
// #if defined(OS_WINDOWS)
//     return (wglGetCurrentContext() == context.hGLRC);
// #elif defined(OS_LINUX_XLIB) || defined(OS_LINUX_XCB_GLX)
//     return (glXGetCurrentContext() == context.glxContext);
// #elif defined(OS_LINUX_XCB)
//     return true;
// #elif defined(OS_APPLE_MACOS)
//     return (CGLGetCurrentContext() == context.cglContext);
// #elif defined(OS_APPLE_IOS)
//     return (false);  // TODO: pick current context off the UIView
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     return (eglGetCurrentContext() == context.context);
// #endif
// }

// ================================================================================================================================
// GPU Window.
// ================================================================================================================================
// typedef enum {
//     KEY_A = 0x41,
//     KEY_B = 0x42,
//     KEY_C = 0x43,
//     KEY_D = 0x44,
//     KEY_E = 0x45,
//     KEY_F = 0x46,
//     KEY_G = 0x47,
//     KEY_H = 0x48,
//     KEY_I = 0x49,
//     KEY_J = 0x4A,
//     KEY_K = 0x4B,
//     KEY_L = 0x4C,
//     KEY_M = 0x4D,
//     KEY_N = 0x4E,
//     KEY_O = 0x4F,
//     KEY_P = 0x50,
//     KEY_Q = 0x51,
//     KEY_R = 0x52,
//     KEY_S = 0x53,
//     KEY_T = 0x54,
//     KEY_U = 0x55,
//     KEY_V = 0x56,
//     KEY_W = 0x57,
//     KEY_X = 0x58,
//     KEY_Y = 0x59,
//     KEY_Z = 0x5A,
//     KEY_RETURN = VK_RETURN,
//     KEY_TAB = VK_TAB,
//     KEY_ESCAPE = VK_ESCAPE,
//     KEY_SHIFT_LEFT = VK_LSHIFT,
//     KEY_CTRL_LEFT = VK_LCONTROL,
//     KEY_ALT_LEFT = VK_LMENU,
//     KEY_CURSOR_UP = VK_UP,
//     KEY_CURSOR_DOWN = VK_DOWN,
//     KEY_CURSOR_LEFT = VK_LEFT,
//     KEY_CURSOR_RIGHT = VK_RIGHT
// } ksKeyboardKey;
//
// typedef enum { MOUSE_LEFT = 0, MOUSE_RIGHT = 1 } ksMouseButton;

// APIENTRY
export fn WndProc(hWnd: c.HWND, message: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) c.LRESULT {
    //     ksGpuWindow* window = (ksGpuWindow*)GetWindowLongPtrA(hWnd, GWLP_USERDATA);
    //
    //     switch (message) {
    //         case WM_SIZE: {
    //             if (window != null) {
    //                 window.windowWidth = (int)LOWORD(lParam);
    //                 window.windowHeight = (int)HIWORD(lParam);
    //             }
    //             return 0;
    //         }
    //         case WM_ACTIVATE: {
    //             if (window != null) {
    //                 window.windowActiveState = !HIWORD(wParam);
    //             }
    //             return 0;
    //         }
    //         case WM_ERASEBKGND: {
    //             return 0;
    //         }
    //         case WM_CLOSE: {
    //             PostQuitMessage(0);
    //             return 0;
    //         }
    //         case WM_KEYDOWN: {
    //             if (window != null) {
    //                 if ((int)wParam >= 0 && (int)wParam < 256) {
    //                     if ((int)wParam != KEY_SHIFT_LEFT && (int)wParam != KEY_CTRL_LEFT && (int)wParam != KEY_ALT_LEFT &&
    //                         (int)wParam != KEY_CURSOR_UP && (int)wParam != KEY_CURSOR_DOWN && (int)wParam != KEY_CURSOR_LEFT &&
    //                         (int)wParam != KEY_CURSOR_RIGHT) {
    //                         window.input.keyInput[(int)wParam] = true;
    //                     }
    //                 }
    //             }
    //             break;
    //         }
    //         case WM_LBUTTONDOWN: {
    //             window.input.mouseInput[MOUSE_LEFT] = true;
    //             window.input.mouseInputX[MOUSE_LEFT] = LOWORD(lParam);
    //             window.input.mouseInputY[MOUSE_LEFT] = window.windowHeight - HIWORD(lParam);
    //             break;
    //         }
    //         case WM_RBUTTONDOWN: {
    //             window.input.mouseInput[MOUSE_RIGHT] = true;
    //             window.input.mouseInputX[MOUSE_RIGHT] = LOWORD(lParam);
    //             window.input.mouseInputY[MOUSE_RIGHT] = window.windowHeight - HIWORD(lParam);
    //             break;
    //         }
    //     }
    return c.DefWindowProcA(hWnd, message, wParam, lParam);
}

fn ksGpuWindow_Destroy(window: *ksGpuWindow) void {
    ksGpuContext_Destroy(&window.context);
    ksGpuDevice_Destroy(&window.device);

    //     if (window.windowFullscreen) {
    //         ChangeDisplaySettingsA(null, 0);
    //         ShowCursor(TRUE);
    //     }
    //
    //     if (window.hDC) {
    //         if (!ReleaseDC(window.hWnd, window.hDC)) {
    //             Error("Failed to release device context.");
    //         }
    //         window.hDC = null;
    //     }
    //
    //     if (window.hWnd) {
    //         if (!DestroyWindow(window.hWnd)) {
    //             Error("Failed to destroy the window.");
    //         }
    //         window.hWnd = null;
    //     }
    //
    //     if (window.hInstance) {
    //         if (!UnregisterClassA(APPLICATION_NAME, window.hInstance)) {
    //             Error("Failed to unregister window class.");
    //         }
    //         window.hInstance = null;
    //     }
}

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
    _ = c.memset(window, 0, @sizeOf(ksGpuWindow));

    window.colorFormat = colorFormat;
    window.depthFormat = depthFormat;
    window.sampleCount = sampleCount;
    window.windowWidth = width;
    window.windowHeight = height;
    window.windowSwapInterval = 1;
    window.windowRefreshRate = 60.0;
    window.windowFullscreen = fullscreen;
    window.windowActive = false;
    window.windowExit = false;
    window.windowActiveState = false;

    const displayDevice: c.LPCSTR = null;

    if (window.windowFullscreen) {
        //     DEVMODEA dmScreenSettings;
        //     memset(&dmScreenSettings, 0, sizeof(dmScreenSettings));
        //     dmScreenSettings.dmSize = sizeof(dmScreenSettings);
        //     dmScreenSettings.dmPelsWidth = width;
        //     dmScreenSettings.dmPelsHeight = height;
        //     dmScreenSettings.dmBitsPerPel = 32;
        //     dmScreenSettings.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_BITSPERPEL;
        //
        //     if (ChangeDisplaySettingsExA(displayDevice, &dmScreenSettings, null, CDS_FULLSCREEN, null) != DISP_CHANGE_SUCCESSFUL) {
        //         Error("The requested fullscreen mode is not supported.");
        //         return false;
        //     }
    }

    var lpDevMode: c.DEVMODEA = undefined;
    _ = c.memset(&lpDevMode, 0, @sizeOf(c.DEVMODEA));
    lpDevMode.dmSize = @sizeOf(c.DEVMODEA);
    lpDevMode.dmDriverExtra = 0;

    if (c.EnumDisplaySettingsA(displayDevice, c.ENUM_CURRENT_SETTINGS, &lpDevMode) != c.FALSE) {
        window.windowRefreshRate = @floatFromInt(lpDevMode.dmDisplayFrequency);
    }

    window.hInstance = c.GetModuleHandleA(null);

    const wc: c.WNDCLASSA = .{
        .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
        .lpfnWndProc = WndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = window.hInstance,
        .hIcon = c.LoadIconA(null, 32517
            // c.IDI_WINLOGO
        ),
        .hCursor = c.LoadCursorA(null, 32512
            // c.IDC_ARROW
        ),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = APPLICATION_NAME,
    };

    if (0 == c.RegisterClassA(&wc)) {
        std.log.err("Failed to register window class.", .{});
        return false;
    }

    var dwExStyle: c.DWORD = 0;
    var dwStyle: c.DWORD = 0;
    if (window.windowFullscreen) {
        dwExStyle = c.WS_EX_APPWINDOW;
        dwStyle = c.WS_POPUP;
        _ = c.ShowCursor(c.FALSE);
    } else {
        // Fixed size window.
        dwExStyle = c.WS_EX_APPWINDOW | c.WS_EX_WINDOWEDGE;
        dwStyle = c.WS_OVERLAPPED | c.WS_CAPTION | c.WS_SYSMENU | c.WS_MINIMIZEBOX;
    }

    var windowRect: c.RECT = .{
        .left = 0,
        .right = width,
        .top = 0,
        .bottom = height,
    };

    _ = c.AdjustWindowRectEx(&windowRect, dwStyle, c.FALSE, dwExStyle);

    if (!window.windowFullscreen) {
        var desktopRect: c.RECT = undefined;
        _ = c.GetWindowRect(c.GetDesktopWindow(), &desktopRect);

        const offsetX = @divTrunc((desktopRect.right - (windowRect.right - windowRect.left)), 2);
        const offsetY = @divTrunc((desktopRect.bottom - (windowRect.bottom - windowRect.top)), 2);

        windowRect.left += offsetX;
        windowRect.right += offsetX;
        windowRect.top += offsetY;
        windowRect.bottom += offsetY;
    }

    window.hWnd = c.CreateWindowExA(dwExStyle, // Extended style for the window
        APPLICATION_NAME, // Class name
        WINDOW_TITLE, // Window title
        dwStyle | // Defined window style
            c.WS_CLIPSIBLINGS | // Required window style
            c.WS_CLIPCHILDREN, // Required window style
        windowRect.left, // Window X position
        windowRect.top, // Window Y position
        windowRect.right - windowRect.left, // Window width
        windowRect.bottom - windowRect.top, // Window height
        null, // No parent window
        null, // No menu
        window.hInstance, // Instance
        null); // No WM_CREATE parameter
    if (null == window.hWnd) {
        ksGpuWindow_Destroy(window);
        std.log.err("Failed to create window.", .{});
        return false;
    }

    _ = c.SetWindowLongPtrA(window.hWnd, c.GWLP_USERDATA, @intCast(@intFromPtr(window)));

    window.hDC = c.GetDC(window.hWnd);
    if (window.hDC == null) {
        ksGpuWindow_Destroy(window);
        std.log.err("Failed to acquire device context.", .{});
        return false;
    }

    _ = ksGpuDevice_Create(&window.device, instance, queueInfo);
    _ = ksGpuContext_CreateForSurface(&window.context, &window.device, queueIndex, colorFormat, depthFormat, sampleCount, window.hInstance, window.hDC);
    ksGpuContext_SetCurrent(&window.context);

    _ = c.gladLoaderLoadGL();

    _ = c.ShowWindow(window.hWnd, c.SW_SHOW);
    _ = c.SetForegroundWindow(window.hWnd);
    _ = c.SetFocus(window.hWnd);

    return true;
}

// Initialize the gl extensions. Note we have to open a window.
var m_window: ksGpuWindow = undefined;
var m_driverInstance: ksDriverInstance = undefined;
var m_queueInfo: ksGpuQueueInfo = undefined;
var m_colorFormat: ksGpuSurfaceColorFormat = .B8G8R8A8;
var m_depthFormat: ksGpuSurfaceDepthFormat = .D24;
var m_sampleCount: ksGpuSampleCount = ._1;
var m_graphicsBinding: c.XrGraphicsBindingOpenGLWin32KHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR };

pub fn binding() *anyopaque {
    return &m_graphicsBinding;
}

pub fn init() void {
    m_window = undefined;
    m_driverInstance = undefined;
    m_queueInfo = undefined;
    m_colorFormat = .B8G8R8A8;
    m_depthFormat = .D24;
    m_sampleCount = ._1;
    m_graphicsBinding = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR };

    if (!ksGpuWindow_Create(&m_window, &m_driverInstance, &m_queueInfo, 0, m_colorFormat, m_depthFormat, m_sampleCount, 640, 480, false)) {
        @panic("Unable to create GL context");
    }

    m_graphicsBinding.hDC = m_window.context.hDC;
    m_graphicsBinding.hGLRC = m_window.context.hGLRC;
}

// void gfxwrapper_opengl_deinit() {
//     //
//     ksGpuWindow_Destroy(&window);
// }
