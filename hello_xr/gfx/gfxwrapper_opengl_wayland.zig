const std = @import("std");
const c = @import("../c.zig").openxr;
// #include "gfxwrapper_opengl.h"
// #include "EGL/eglplatform.h"
// #include "glad/egl.h"
//
// #if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
// #define OS_WINDOWS
// #elif defined(__ANDROID__)
// #define OS_ANDROID
// #elif defined(__APPLE__)
// #define OS_APPLE
// #include <Availability.h>
// #if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED
// #define OS_APPLE_IOS
// #elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED
// #define OS_APPLE_MACOS
// #endif
// #elif defined(__linux__)
// #define OS_LINUX
// #else
// #error "unknown platform"
// #endif
//
// /*
// ================================
// Platform headers / declarations
// ================================
// */
//
// #elif defined(OS_LINUX)
//
// #define OPENGL_VERSION_MAJOR 4
// #define OPENGL_VERSION_MINOR 5
// #define GLSL_VERSION "430"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 0  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer
//
// #if !defined(_XOPEN_SOURCE)
// #if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
// #define _XOPEN_SOURCE 600
// #else
// #define _XOPEN_SOURCE 500
// #endif
// #endif
//
// #include <time.h>      // for timespec
// #include <sys/time.h>  // for gettimeofday()
// #if !defined(__USE_UNIX98)
// #define __USE_UNIX98 1  // for pthread_mutexattr_settype
// #endif
// #include <pthread.h>  // for pthread_create() etc.
// #include <malloc.h>   // for memalign
//

// #elif defined(OS_LINUX_WAYLAND)
// #define XR_USE_PLATFORM_WAYLAND 1

const wl = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-client-protocol.h");
    @cInclude("wayland-egl.h");
    @cInclude("glad/egl.h");
    @cInclude("linux/input.h");
    @cInclude("poll.h");
    @cInclude("unistd.h");
    // @cInclude("xdg-shell-unstable-v6.h");
});

// #endif
//
// #define GRAPHICS_API_OPENGL 1
// #define OUTPUT_PATH ""
//
// #elif defined(OS_APPLE_MACOS)
//
// // Apple is still at OpenGL 4.1
// #define OPENGL_VERSION_MAJOR 4
// #define OPENGL_VERSION_MINOR 1
// #define GLSL_VERSION "410"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 0  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer
// #define XR_USE_PLATFORM_MACOS 1
//
// #include <sys/param.h>
// #include <sys/sysctl.h>
// #include <sys/time.h>
// #include <pthread.h>
// #include <ApplicationServices/ApplicationServices.h>
// #if defined(__OBJC__)
// #import <Cocoa/Cocoa.h>
// #endif
//
// #include <glad/gl.h>
//
// #undef MAX
// #undef MIN
//
// #define GRAPHICS_API_OPENGL 1
// #define OUTPUT_PATH ""
//
// // Undocumented CGS and CGL
// typedef void* CGSConnectionID;
// typedef int CGSWindowID;
// typedef int CGSSurfaceID;
//
// CGLError CGLSetSurface(CGLContextObj ctx, CGSConnectionID cid, CGSWindowID wid, CGSSurfaceID sid);
// CGLError CGLGetSurface(CGLContextObj ctx, CGSConnectionID* cid, CGSWindowID* wid, CGSSurfaceID* sid);
// CGLError CGLUpdateContext(CGLContextObj ctx);
//
// #elif defined(OS_APPLE_IOS)
//
// // Assume iOS 7+ which is GLES 3.0
// #define OPENGL_VERSION_MAJOR 3
// #define OPENGL_VERSION_MINOR 0
// #define GLSL_VERSION "300 es"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 0  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer
// #define XR_USE_PLATFORM_IOS 1
//
// #import <Foundation/Foundation.h>
// #import <QuartzCore/QuartzCore.h>
// #import <UIKit/UIKit.h>
// #include <glad/gl.h>
// #include <sys/sysctl.h>
//
// #define GRAPHICS_API_OPENGL_ES 1
//
// #elif defined(OS_ANDROID)
//
// #define OPENGL_VERSION_MAJOR 3
// #define OPENGL_VERSION_MINOR 2
// #define GLSL_VERSION "320 es"
// #define SPIRV_VERSION "99"
// #define USE_SYNC_OBJECT 1  // 0 = GLsync, 1 = EGLSyncKHR, 2 = storage buffer
//
// #include <time.h>
// #include <unistd.h>
// #include <dirent.h>  // for opendir/closedir
// #include <pthread.h>
// #include <malloc.h>                     // for memalign
// #include <dlfcn.h>                      // for dlopen
// #include <sys/prctl.h>                  // for prctl( PR_SET_NAME )
// #include <sys/stat.h>                   // for gettid
// #include <sys/syscall.h>                // for syscall
// #include <android/log.h>                // for __android_log_print
// #include <android/input.h>              // for AKEYCODE_ etc.
// #include <android/window.h>             // for AWINDOW_FLAG_KEEP_SCREEN_ON
// #include <android/native_window_jni.h>  // for native window JNI
// #include <glad/egl.h>
//
// #define GRAPHICS_API_OPENGL_ES 1
// #define OUTPUT_PATH "/sdcard/"
//
// typedef struct {
//     JavaVM* vm;        // Java Virtual Machine
//     JNIEnv* env;       // Thread specific environment
//     jobject activity;  // Java activity object
// } Java_t;
//
// #endif
//
// /*
// ================================
// Common headers
// ================================
// */
//
// #include <stdio.h>
// #include <stdlib.h>
// #include <stdarg.h>
// #include <stdbool.h>
// #include <stdint.h>
// #include <math.h>
// #include <assert.h>
// #include <string.h>  // for memset
// #include <errno.h>   // for EBUSY, ETIMEDOUT etc.
// #include <ctype.h>   // for isspace, isdigit
//
// /*
// ================================
// Common defines
// ================================
// */
//
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
//
// #if defined(OS_ANDROID)
// #define ES_HIGHP "highp"  // GLSL "310 es" requires a precision qualifier on a image2D
// #else
// #define ES_HIGHP ""  // GLSL "430" disallows a precision qualifier on a image2D
// #endif
//
// /*
// ================================================================================================================================
//
// Driver Instance.
//
// ksDriverInstance
//
// bool ksDriverInstance_Create( ksDriverInstance * instance );
// void ksDriverInstance_Destroy( ksDriverInstance * instance );
//
// ================================================================================================================================
// */

const ksDriverInstance = struct {
    placeholder: c_int = undefined,
};

// bool ksDriverInstance_Create(ksDriverInstance* instance);
// void ksDriverInstance_Destroy(ksDriverInstance* instance);
//
// /*
// ================================================================================================================================
//
// GPU device.
//
// ksGpuQueueProperty
// ksGpuQueuePriority
// ksGpuQueueInfo
// ksGpuDevice
//
// bool ksGpuDevice_Create( ksGpuDevice * device, ksDriverInstance * instance, const ksGpuQueueInfo * queueInfo );
// void ksGpuDevice_Destroy( ksGpuDevice * device );
//
// ================================================================================================================================
// */

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

// bool ksGpuDevice_Create(ksGpuDevice* device, ksDriverInstance* instance, const ksGpuQueueInfo* queueInfo);
// void ksGpuDevice_Destroy(ksGpuDevice* device);
//
// /*
// ================================================================================================================================
//
// GPU context.
//
// A context encapsulates a queue that is used to submit command buffers.
// A context can only be used by a single thread.
// For optimal performance a context should only be created at load time, not at runtime.
//
// ksGpuContext
// ksGpuSurfaceColorFormat
// ksGpuSurfaceDepthFormat
// ksGpuSampleCount
//
// bool ksGpuContext_CreateShared( ksGpuContext * context, const ksGpuContext * other, const int queueIndex );
// void ksGpuContext_Destroy( ksGpuContext * context );
// void ksGpuContext_SetCurrent( ksGpuContext * context );
// void ksGpuContext_UnsetCurrent( ksGpuContext * context );
// bool ksGpuContext_CheckCurrent( ksGpuContext * context );
//
// bool ksGpuContext_CreateForSurface( ksGpuContext * context, const ksGpuDevice * device, const int queueIndex,
//                                                                                 const ksGpuSurfaceColorFormat colorFormat,
//                                                                                 const ksGpuSurfaceDepthFormat depthFormat,
//                                                                                 const ksGpuSampleCount sampleCount,
//                                                                                 ... );
//
// ================================================================================================================================
// */

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

// typedef struct {
//     unsigned char redBits;
//     unsigned char greenBits;
//     unsigned char blueBits;
//     unsigned char alphaBits;
//     unsigned char colorBits;
//     unsigned char depthBits;
// } ksGpuSurfaceBits;
//
// bool ksGpuContext_CreateShared(ksGpuContext* context, const ksGpuContext* other, int queueIndex);
// void ksGpuContext_SetCurrent(ksGpuContext* context);
// void ksGpuContext_UnsetCurrent(ksGpuContext* context);
// bool ksGpuContext_CheckCurrent(ksGpuContext* context);
//
// /*
// ================================================================================================================================
//
// GPU Window.
//
// Window with associated GPU context for GPU accelerated rendering.
// For optimal performance a window should only be created at load time, not at runtime.
// Because on some platforms the OS/drivers use thread local storage, ksGpuWindow *must* be created
// and destroyed on the same thread that will actually render to the window and swap buffers.
//
// ksGpuWindow
// ksGpuWindowEvent
// ksGpuWindowInput
// ksKeyboardKey
// ksMouseButton
//
// bool ksGpuWindow_Create( ksGpuWindow * window, ksDriverInstance * instance,
//                                                 const ksGpuQueueInfo * queueInfo, const int queueIndex,
//                                                 const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat
// depthFormat,
//                                                 const ksGpuSampleCount sampleCount, const int width, const int height, const bool
// fullscreen );
// void ksGpuWindow_Destroy( ksGpuWindow * window );
//
// ================================================================================================================================
// */

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

const ksGpuWindow = struct {
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

// /*
// ================================================================================================================================
//
// EGL error checking.
//
// ================================================================================================================================
// */

// #if defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//
// #define EGL(func)                                                      \
//     do {                                                               \
//         if (func == EGL_FALSE) {                                       \
//             Error(#func " failed: %s", EglErrorString(eglGetError())); \
//         }                                                              \
//     } while (0)
//
// static const char* EglErrorString(const EGLint error) {
//     switch (error) {
//         case EGL_SUCCESS:
//             return "EGL_SUCCESS";
//         case EGL_NOT_INITIALIZED:
//             return "EGL_NOT_INITIALIZED";
//         case EGL_BAD_ACCESS:
//             return "EGL_BAD_ACCESS";
//         case EGL_BAD_ALLOC:
//             return "EGL_BAD_ALLOC";
//         case EGL_BAD_ATTRIBUTE:
//             return "EGL_BAD_ATTRIBUTE";
//         case EGL_BAD_CONTEXT:
//             return "EGL_BAD_CONTEXT";
//         case EGL_BAD_CONFIG:
//             return "EGL_BAD_CONFIG";
//         case EGL_BAD_CURRENT_SURFACE:
//             return "EGL_BAD_CURRENT_SURFACE";
//         case EGL_BAD_DISPLAY:
//             return "EGL_BAD_DISPLAY";
//         case EGL_BAD_SURFACE:
//             return "EGL_BAD_SURFACE";
//         case EGL_BAD_MATCH:
//             return "EGL_BAD_MATCH";
//         case EGL_BAD_PARAMETER:
//             return "EGL_BAD_PARAMETER";
//         case EGL_BAD_NATIVE_PIXMAP:
//             return "EGL_BAD_NATIVE_PIXMAP";
//         case EGL_BAD_NATIVE_WINDOW:
//             return "EGL_BAD_NATIVE_WINDOW";
//         case EGL_CONTEXT_LOST:
//             return "EGL_CONTEXT_LOST";
//         default:
//             return "unknown";
//     }
// }
//
// #endif
//
// /*
// ================================================================================================================================
//
// OpenGL extensions.
//
// ================================================================================================================================
// */
//
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
//
// /*
// ================================================================================================================================
//
// Driver Instance.
//
// ================================================================================================================================
// */
//
// bool ksDriverInstance_Create(ksDriverInstance* instance) {
//     memset(instance, 0, sizeof(ksDriverInstance));
//     return true;
// }
//
// void ksDriverInstance_Destroy(ksDriverInstance* instance) { memset(instance, 0, sizeof(ksDriverInstance)); }
//
// /*
// ================================================================================================================================
//
// GPU Device.
//
// ================================================================================================================================
// */
//
// bool ksGpuDevice_Create(ksGpuDevice* device, ksDriverInstance* instance, const ksGpuQueueInfo* queueInfo) {
//     /*
//             Use an extensions to select the appropriate device:
//             https://www.opengl.org/registry/specs/NV/gpu_affinity.txt
//             https://www.opengl.org/registry/specs/AMD/wgl_gpu_association.txt
//             https://www.opengl.org/registry/specs/AMD/glx_gpu_association.txt
//
//             On Linux configure each GPU to use a separate X screen and then select
//             the X screen to render to.
//     */
//
//     memset(device, 0, sizeof(ksGpuDevice));
//
//     device.instance = instance;
//     device.queueInfo = *queueInfo;
//
//     return true;
// }

fn ksGpuDevice_Destroy(device: *ksGpuDevice) void {
    _ = device;
    // memset(device, 0, sizeof(ksGpuDevice));
}

// /*
// ================================================================================================================================
//
// GPU Context.
//
// ================================================================================================================================
// */
//
// ksGpuSurfaceBits ksGpuContext_BitsForSurfaceFormat(const ksGpuSurfaceColorFormat colorFormat,
//                                                    const ksGpuSurfaceDepthFormat depthFormat) {
//     ksGpuSurfaceBits bits;
//     bits.redBits = ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R8G8B8A8)
//                         ? 8
//                         : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B8G8R8A8)
//                                ? 8
//                                : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_R5G6B5)
//                                       ? 5
//                                       : ((colorFormat == KS_GPU_SURFACE_COLOR_FORMAT_B5G6R5) ? 5 : 8))));
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
//     bits.depthBits =
//         ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D16) ? 16 : ((depthFormat == KS_GPU_SURFACE_DEPTH_FORMAT_D24) ? 24 : 0));
//     return bits;
// }
//
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
// }
//
// #if defined(OS_WINDOWS)
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, const int queueIndex,
//                                           const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                           const ksGpuSampleCount sampleCount, HINSTANCE hInstance, HDC hDC) {
//     UNUSED_PARM(queueIndex);
//
//     context.device = device;
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     PIXELFORMATDESCRIPTOR pfd = {
//         sizeof(PIXELFORMATDESCRIPTOR),
//         1,                        // version
//         PFD_DRAW_TO_WINDOW |      // must support windowed
//             PFD_SUPPORT_OPENGL |  // must support OpenGL
//             PFD_DOUBLEBUFFER,     // must support double buffering
//         PFD_TYPE_RGBA,            // iPixelType
//         bits.colorBits,           // cColorBits
//         0,
//         0,  // cRedBits, cRedShift
//         0,
//         0,  // cGreenBits, cGreenShift
//         0,
//         0,  // cBlueBits, cBlueShift
//         0,
//         0,               // cAlphaBits, cAlphaShift
//         0,               // cAccumBits
//         0,               // cAccumRedBits
//         0,               // cAccumGreenBits
//         0,               // cAccumBlueBits
//         0,               // cAccumAlphaBits
//         bits.depthBits,  // cDepthBits
//         0,               // cStencilBits
//         0,               // cAuxBuffers
//         PFD_MAIN_PLANE,  // iLayerType
//         0,               // bReserved
//         0,               // dwLayerMask
//         0,               // dwVisibleMask
//         0                // dwDamageMask
//     };
//
//     HWND localWnd = null;
//     HDC localDC = hDC;
//
//     if (sampleCount > KS_GPU_SAMPLE_COUNT_1) {
//         // A valid OpenGL context is needed to get OpenGL extensions including wglChoosePixelFormatARB
//         // and wglCreateContextAttribsARB. A device context with a valid pixel format is needed to create
//         // an OpenGL context. However, once a pixel format is set on a device context it is final.
//         // Therefore a pixel format is set on the device context of a temporary window to create a context
//         // to get the extensions for multi-sampling.
//         localWnd = CreateWindowA(APPLICATION_NAME, "temp", 0, 0, 0, 0, 0, null, null, hInstance, null);
//         localDC = GetDC(localWnd);
//     }
//
//     int pixelFormat = ChoosePixelFormat(localDC, &pfd);
//     if (pixelFormat == 0) {
//         Error("Failed to find a suitable pixel format.");
//         return false;
//     }
//
//     if (!SetPixelFormat(localDC, pixelFormat, &pfd)) {
//         Error("Failed to set the pixel format.");
//         return false;
//     }
//
//     // Now that the pixel format is set, create a temporary context to get the extensions.
//     {
//         gladLoaderLoadWGL(localDC);
//         HGLRC hGLRC = wglCreateContext(localDC);
//         wglMakeCurrent(localDC, hGLRC);
//
//         gladLoaderLoadWGL(localDC);
//
//         wglMakeCurrent(null, null);
//         wglDeleteContext(hGLRC);
//     }
//
//     if (sampleCount > KS_GPU_SAMPLE_COUNT_1) {
//         // Release the device context and destroy the window that were created to get extensions.
//         ReleaseDC(localWnd, localDC);
//         DestroyWindow(localWnd);
//
//         int pixelFormatAttribs[] = {WGL_DRAW_TO_WINDOW_ARB,
//                                     GL_TRUE,
//                                     WGL_SUPPORT_OPENGL_ARB,
//                                     GL_TRUE,
//                                     WGL_DOUBLE_BUFFER_ARB,
//                                     GL_TRUE,
//                                     WGL_PIXEL_TYPE_ARB,
//                                     WGL_TYPE_RGBA_ARB,
//                                     WGL_COLOR_BITS_ARB,
//                                     bits.colorBits,
//                                     WGL_DEPTH_BITS_ARB,
//                                     bits.depthBits,
//                                     WGL_SAMPLE_BUFFERS_ARB,
//                                     1,
//                                     WGL_SAMPLES_ARB,
//                                     sampleCount,
//                                     0};
//
//         unsigned int numPixelFormats = 0;
//
//         if (!wglChoosePixelFormatARB(hDC, pixelFormatAttribs, null, 1, &pixelFormat, &numPixelFormats) || numPixelFormats == 0) {
//             Error("Failed to find MSAA pixel format.");
//             return false;
//         }
//
//         memset(&pfd, 0, sizeof(pfd));
//
//         if (!DescribePixelFormat(hDC, pixelFormat, sizeof(PIXELFORMATDESCRIPTOR), &pfd)) {
//             Error("Failed to describe the pixel format.");
//             return false;
//         }
//
//         if (!SetPixelFormat(hDC, pixelFormat, &pfd)) {
//             Error("Failed to set the pixel format.");
//             return false;
//         }
//     }
//
//     int contextAttribs[] = {WGL_CONTEXT_MAJOR_VERSION_ARB,
//                             OPENGL_VERSION_MAJOR,
//                             WGL_CONTEXT_MINOR_VERSION_ARB,
//                             OPENGL_VERSION_MINOR,
//                             WGL_CONTEXT_PROFILE_MASK_ARB,
//                             WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
//                             WGL_CONTEXT_FLAGS_ARB,
//                             WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB | WGL_CONTEXT_DEBUG_BIT_ARB,
//                             0};
//
//     context.hDC = hDC;
//     context.hGLRC = wglCreateContextAttribsARB(hDC, null, contextAttribs);
//     if (!context.hGLRC) {
//         Error("Failed to create GL context.");
//         return false;
//     }
//
//     wglMakeCurrent(hDC, context.hGLRC);
//
//     return true;
// }
//
// #elif defined(OS_LINUX_XLIB) || defined(OS_LINUX_XCB_GLX)
//
// static int glxGetFBConfigAttrib2(Display* dpy, GLXFBConfig config, int attribute) {
//     int value;
//     glXGetFBConfigAttrib(dpy, config, attribute, &value);
//     return value;
// }
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, const int queueIndex,
//                                           const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                           const ksGpuSampleCount sampleCount, Display* xDisplay, int xScreen) {
//     UNUSED_PARM(queueIndex);
//
//     gladLoaderLoadGLX(xDisplay, xScreen);
//
//     context.device = device;
//
//     int glxErrorBase;
//     int glxEventBase;
//     if (!glXQueryExtension(xDisplay, &glxErrorBase, &glxEventBase)) {
//         Error("X display does not support the GLX extension.");
//         return false;
//     }
//
//     int glxVersionMajor;
//     int glxVersionMinor;
//     if (!glXQueryVersion(xDisplay, &glxVersionMajor, &glxVersionMinor)) {
//         Error("Unable to retrieve GLX version.");
//         return false;
//     }
//
//     int fbConfigCount = 0;
//     GLXFBConfig* fbConfigs = glXGetFBConfigs(xDisplay, xScreen, &fbConfigCount);
//     if (fbConfigCount == 0) {
//         Error("No valid framebuffer configurations found.");
//         return false;
//     }
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     bool foundFbConfig = false;
//     for (int i = 0; i < fbConfigCount; i++) {
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_FBCONFIG_ID) == 0) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_VISUAL_ID) == 0) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_DOUBLEBUFFER) == 0) {
//             continue;
//         }
//         if ((glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_RENDER_TYPE) & GLX_RGBA_BIT) == 0) {
//             continue;
//         }
//         if ((glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_DRAWABLE_TYPE) & GLX_WINDOW_BIT) == 0) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_RED_SIZE) != bits.redBits) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_GREEN_SIZE) != bits.greenBits) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_BLUE_SIZE) != bits.blueBits) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_ALPHA_SIZE) != bits.alphaBits) {
//             continue;
//         }
//         if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_DEPTH_SIZE) != bits.depthBits) {
//             continue;
//         }
//         if (sampleCount > KS_GPU_SAMPLE_COUNT_1) {
//             if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_SAMPLE_BUFFERS) != 1) {
//                 continue;
//             }
//             if (glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_SAMPLES) != (int)sampleCount) {
//                 continue;
//             }
//         }
//
//         context.visualid = glxGetFBConfigAttrib2(xDisplay, fbConfigs[i], GLX_VISUAL_ID);
//         context.glxFBConfig = fbConfigs[i];
//         foundFbConfig = true;
//         break;
//     }
//
//     XFree(fbConfigs);
//
//     if (!foundFbConfig) {
//         Error("Failed to to find desired framebuffer configuration.");
//         return false;
//     }
//
//     context.xDisplay = xDisplay;
//
//     int attribs[] = {GLX_CONTEXT_MAJOR_VERSION_ARB,
//                      OPENGL_VERSION_MAJOR,
//                      GLX_CONTEXT_MINOR_VERSION_ARB,
//                      OPENGL_VERSION_MINOR,
//                      GL_CONTEXT_PROFILE_MASK,
//                      GL_CONTEXT_CORE_PROFILE_BIT,
//                      GLX_CONTEXT_FLAGS_ARB,
//                      GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
//                      0};
//
//     context.glxContext = glXCreateContextAttribsARB(xDisplay,              // Display * dpy
//                                                      context.glxFBConfig,  // GLXFBConfig config
//                                                      null,                  // GLXContext share_context
//                                                      True,                  // Bool   direct
//                                                      attribs);              // const int * attrib_list
//
//     if (context.glxContext == null) {
//         Error("Unable to create GLX context.");
//         return false;
//     }
//
//     if (!glXIsDirect(xDisplay, context.glxContext)) {
//         Error("Unable to create direct rendering context.");
//         return false;
//     }
//
//     return true;
// }
//
// #elif defined(OS_LINUX_XCB)
//
// static uint32_t xcb_glx_get_property(const uint32_t* properties, const uint32_t numProperties, uint32_t propertyName) {
//     for (uint32_t i = 0; i < numProperties; i++) {
//         if (properties[i * 2 + 0] == propertyName) {
//             return properties[i * 2 + 1];
//         }
//     }
//     return 0;
// }
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, const int queueIndex,
//                                           const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                           const ksGpuSampleCount sampleCount, xcb_connection_t* connection, int screen_number) {
//     UNUSED_PARM(queueIndex);
//
//     context.device = device;
//
//     xcb_glx_query_version_cookie_t glx_query_version_cookie =
//         xcb_glx_query_version(connection, OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR);
//     xcb_glx_query_version_reply_t* glx_query_version_reply =
//         xcb_glx_query_version_reply(connection, glx_query_version_cookie, null);
//     if (glx_query_version_reply == null) {
//         Error("Unable to retrieve GLX version.");
//         return false;
//     }
//     free(glx_query_version_reply);
//
//     xcb_glx_get_fb_configs_cookie_t get_fb_configs_cookie = xcb_glx_get_fb_configs(connection, screen_number);
//     xcb_glx_get_fb_configs_reply_t* get_fb_configs_reply = xcb_glx_get_fb_configs_reply(connection, get_fb_configs_cookie, null);
//
//     if (get_fb_configs_reply == null || get_fb_configs_reply.num_FB_configs == 0) {
//         Error("No valid framebuffer configurations found.");
//         return false;
//     }
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     const uint32_t* fb_configs_properties = xcb_glx_get_fb_configs_property_list(get_fb_configs_reply);
//     const uint32_t fb_configs_num_properties = get_fb_configs_reply.num_properties;
//
//     bool foundFbConfig = false;
//     for (uint32_t i = 0; i < get_fb_configs_reply.num_FB_configs; i++) {
//         const uint32_t* fb_config = fb_configs_properties + i * fb_configs_num_properties * 2;
//
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_FBCONFIG_ID) == 0) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_VISUAL_ID) == 0) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_DOUBLEBUFFER) == 0) {
//             continue;
//         }
//         if ((xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_RENDER_TYPE) & GLX_RGBA_BIT) == 0) {
//             continue;
//         }
//         if ((xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_DRAWABLE_TYPE) & GLX_WINDOW_BIT) == 0) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_RED_SIZE) != bits.redBits) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_GREEN_SIZE) != bits.greenBits) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_BLUE_SIZE) != bits.blueBits) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_ALPHA_SIZE) != bits.alphaBits) {
//             continue;
//         }
//         if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_DEPTH_SIZE) != bits.depthBits) {
//             continue;
//         }
//         if (sampleCount > KS_GPU_SAMPLE_COUNT_1) {
//             if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_SAMPLE_BUFFERS) != 1) {
//                 continue;
//             }
//             if (xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_SAMPLES) != sampleCount) {
//                 continue;
//             }
//         }
//
//         context.fbconfigid = xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_FBCONFIG_ID);
//         context.visualid = xcb_glx_get_property(fb_config, fb_configs_num_properties, GLX_VISUAL_ID);
//         foundFbConfig = true;
//         break;
//     }
//
//     free(get_fb_configs_reply);
//
//     if (!foundFbConfig) {
//         Error("Failed to to find desired framebuffer configuration.");
//         return false;
//     }
//
//     context.connection = connection;
//     context.screen_number = screen_number;
//
//     // Create the context.
//     uint32_t attribs[] = {GLX_CONTEXT_MAJOR_VERSION_ARB,
//                           OPENGL_VERSION_MAJOR,
//                           GLX_CONTEXT_MINOR_VERSION_ARB,
//                           OPENGL_VERSION_MINOR,
//                           GLX_CONTEXT_PROFILE_MASK_ARB,
//                           GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
//                           GLX_CONTEXT_FLAGS_ARB,
//                           GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
//                           0};
//
//     context.glxContext = xcb_generate_id(connection);
//     xcb_glx_create_context_attribs_arb(connection,           // xcb_connection_t * connection
//                                        context.glxContext,  // xcb_glx_context_t context
//                                        context.fbconfigid,  // xcb_glx_fbconfig_t fbconfig
//                                        screen_number,        // uint32_t    screen
//                                        0,                    // xcb_glx_context_t share_list
//                                        1,                    // uint8_t    is_direct
//                                        4,                    // uint32_t    num_attribs
//                                        attribs);             // const uint32_t *  attribs
//
//     // Make sure the context is direct.
//     xcb_generic_error_t* error;
//     xcb_glx_is_direct_cookie_t glx_is_direct_cookie = xcb_glx_is_direct_unchecked(connection, context.glxContext);
//     xcb_glx_is_direct_reply_t* glx_is_direct_reply = xcb_glx_is_direct_reply(connection, glx_is_direct_cookie, &error);
//     const bool is_direct = (glx_is_direct_reply != null && glx_is_direct_reply.is_direct);
//     free(glx_is_direct_reply);
//
//     if (!is_direct) {
//         Error("Unable to create direct rendering context.");
//         return false;
//     }
//
//     return true;
// }
//
// #elif defined(OS_LINUX_WAYLAND)
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, struct wl_display* native_display) {
//     context.device = device;
//
//     if (gladLoaderLoadEGL(null) == 0) {
//         return false;
//     }
//
//     EGLint numConfigs;
//     EGLint majorVersion;
//     EGLint minorVersion;
//
//     // clang-format off
//     EGLint fbAttribs[] = {
//         EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
//         EGL_RENDERABLE_TYPE, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
//         EGL_RED_SIZE, 8,
//         EGL_GREEN_SIZE, 8,
//         EGL_BLUE_SIZE, 8,
//         EGL_NONE,
//     };
//
//     EGLint contextAttribs[] = {
//         EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
//         EGL_CONTEXT_CLIENT_VERSION, OPENGL_VERSION_MAJOR,
//         EGL_CONTEXT_MINOR_VERSION, OPENGL_VERSION_MINOR,
//         EGL_NONE,
//     };
//     // clang-format on
//
//     context.display = eglGetDisplay(native_display);
//     if (context.display == EGL_NO_DISPLAY) {
//         Error("Could not create EGL Display.");
//         return false;
//     }
//
//     if (!eglInitialize(context.display, &majorVersion, &minorVersion)) {
//         Error("eglInitialize failed.");
//         return false;
//     }
//
//     printf("Initialized EGL context version %d.%d\n", majorVersion, minorVersion);
//     if (gladLoaderLoadEGL(context.display) == 0) {
//         return false;
//     }
//
//     EGLBoolean ret = eglGetConfigs(context.display, null, 0, &numConfigs);
//     if (ret != EGL_TRUE || numConfigs == 0) {
//         Error("eglGetConfigs failed.");
//         return false;
//     }
//
//     ret = eglChooseConfig(context.display, fbAttribs, &context.config, 1, &numConfigs);
//     if (ret != EGL_TRUE || numConfigs != 1) {
//         Error("eglChooseConfig failed.");
//         return false;
//     }
//
//     context.mainSurface = eglCreateWindowSurface(context.display, context.config, context.native_window, null);
//     if (context.mainSurface == EGL_NO_SURFACE) {
//         Error("eglCreateWindowSurface failed");
//         return false;
//     }
//
//     eglBindAPI(EGL_OPENGL_API);
//
//     context.context = eglCreateContext(context.display, context.config, EGL_NO_CONTEXT, contextAttribs);
//     if (context.context == EGL_NO_CONTEXT) {
//         Error("Could not create OpenGL context.");
//         return false;
//     }
//
//     if (!eglMakeCurrent(context.display, context.mainSurface, context.mainSurface, context.context)) {
//         Error("Could not make the current context current.");
//         return false;
//     }
//
//     return true;
// }
//
// #elif defined(OS_APPLE_MACOS)
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, const int queueIndex,
//                                           const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                           const ksGpuSampleCount sampleCount, CGDirectDisplayID display) {
//     UNUSED_PARM(queueIndex);
//
//     context.device = device;
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {NSOpenGLPFAMinimumPolicy,
//                                                             1,
//                                                             NSOpenGLPFAScreenMask,
//                                                             CGDisplayIDToOpenGLDisplayMask(display),
//                                                             NSOpenGLPFAAccelerated,
//                                                             NSOpenGLPFAOpenGLProfile,
//                                                             NSOpenGLProfileVersion3_2Core,
//                                                             NSOpenGLPFADoubleBuffer,
//                                                             NSOpenGLPFAColorSize,
//                                                             bits.colorBits,
//                                                             NSOpenGLPFADepthSize,
//                                                             bits.depthBits,
//                                                             NSOpenGLPFASampleBuffers,
//                                                             (sampleCount > KS_GPU_SAMPLE_COUNT_1),
//                                                             NSOpenGLPFASamples,
//                                                             sampleCount,
//                                                             0};
//
//     NSOpenGLPixelFormat* pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes] autorelease];
//     if (pixelFormat == nil) {
//         Error("Failed : NSOpenGLPixelFormat.");
//         return false;
//     }
//     context.nsContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
//     if (context.nsContext == nil) {
//         Error("Failed : NSOpenGLContext.");
//         return false;
//     }
//
//     context.cglContext = [context.nsContext CGLContextObj];
//
//     return true;
// }
//
// #elif defined(OS_ANDROID)
//
// static bool ksGpuContext_CreateForSurface(ksGpuContext* context, const ksGpuDevice* device, const int queueIndex,
//                                           const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                           const ksGpuSampleCount sampleCount, EGLDisplay display) {
//     context.device = device;
//
//     context.display = display;
//
//     // Do NOT use eglChooseConfig, because the Android EGL code pushes in multisample
//     // flags in eglChooseConfig when the user has selected the "force 4x MSAA" option in
//     // settings, and that is completely wasted on the time warped frontbuffer.
//     enum { MAX_CONFIGS = 1024 };
//     EGLConfig configs[MAX_CONFIGS];
//     EGLint numConfigs = 0;
//     EGL(eglGetConfigs(display, configs, MAX_CONFIGS, &numConfigs));
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     // clang-format off
//     const EGLint configAttribs[] = {
//         EGL_RED_SIZE, bits.redBits,
//         EGL_GREEN_SIZE, bits.greenBits,
//         EGL_BLUE_SIZE, bits.blueBits,
//         EGL_ALPHA_SIZE, bits.alphaBits,
//         EGL_DEPTH_SIZE, bits.depthBits,
//         // EGL_STENCIL_SIZE, 0,
//         EGL_SAMPLE_BUFFERS, (sampleCount > KS_GPU_SAMPLE_COUNT_1),
//         EGL_SAMPLES, (sampleCount > KS_GPU_SAMPLE_COUNT_1) ? sampleCount : 0,
//         EGL_NONE,
//     };
//     // clang-format on
//
//     context.config = 0;
//     for (int i = 0; i < numConfigs; i++) {
//         EGLint value = 0;
//
//         eglGetConfigAttrib(display, configs[i], EGL_RENDERABLE_TYPE, &value);
//         if ((value & EGL_OPENGL_ES3_BIT) != EGL_OPENGL_ES3_BIT) {
//             continue;
//         }
//
//         // Without EGL_KHR_surfaceless_context, the config needs to support both pbuffers and window surfaces.
//         eglGetConfigAttrib(display, configs[i], EGL_SURFACE_TYPE, &value);
//         if ((value & (EGL_WINDOW_BIT | EGL_PBUFFER_BIT)) != (EGL_WINDOW_BIT | EGL_PBUFFER_BIT)) {
//             continue;
//         }
//
//         int j = 0;
//         for (; configAttribs[j] != EGL_NONE; j += 2) {
//             eglGetConfigAttrib(display, configs[i], configAttribs[j], &value);
//             if (value != configAttribs[j + 1]) {
//                 break;
//             }
//         }
//         if (configAttribs[j] == EGL_NONE) {
//             context.config = configs[i];
//             break;
//         }
//     }
//     if (context.config == 0) {
//         Error("Failed to find EGLConfig");
//         return false;
//     }
//
//     EGLint contextAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, OPENGL_VERSION_MAJOR, EGL_NONE, EGL_NONE, EGL_NONE};
//     // Use the default priority if KS_GPU_QUEUE_PRIORITY_MEDIUM is selected.
//     const ksGpuQueuePriority priority = device.queueInfo.queuePriorities[queueIndex];
//     if (priority != KS_GPU_QUEUE_PRIORITY_MEDIUM) {
//         contextAttribs[2] = EGL_CONTEXT_PRIORITY_LEVEL_IMG;
//         contextAttribs[3] = (priority == KS_GPU_QUEUE_PRIORITY_LOW) ? EGL_CONTEXT_PRIORITY_LOW_IMG : EGL_CONTEXT_PRIORITY_HIGH_IMG;
//     }
//     context.context = eglCreateContext(display, context.config, EGL_NO_CONTEXT, contextAttribs);
//     if (context.context == EGL_NO_CONTEXT) {
//         Error("eglCreateContext() failed: %s", EglErrorString(eglGetError()));
//         return false;
//     }
//
//     const EGLint surfaceAttribs[] = {EGL_WIDTH, 16, EGL_HEIGHT, 16, EGL_NONE};
//     context.tinySurface = eglCreatePbufferSurface(display, context.config, surfaceAttribs);
//     if (context.tinySurface == EGL_NO_SURFACE) {
//         Error("eglCreatePbufferSurface() failed: %s", EglErrorString(eglGetError()));
//         eglDestroyContext(display, context.context);
//         context.context = EGL_NO_CONTEXT;
//         return false;
//     }
//     context.mainSurface = context.tinySurface;
//
//     return true;
// }
//
// #endif
//
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

// void ksGpuContext_SetCurrent(ksGpuContext* context) {
// #if defined(OS_WINDOWS)
//     wglMakeCurrent(context.hDC, context.hGLRC);
// #elif defined(OS_LINUX_XLIB) || defined(OS_LINUX_XCB_GLX)
//     glXMakeCurrent(context.xDisplay, context.glxDrawable, context.glxContext);
// #elif defined(OS_LINUX_XCB)
//     xcb_glx_make_current_cookie_t glx_make_current_cookie =
//         xcb_glx_make_current(context.connection, context.glxDrawable, context.glxContext, 0);
//     xcb_glx_make_current_reply_t* glx_make_current_reply =
//         xcb_glx_make_current_reply(context.connection, glx_make_current_cookie, null);
//     context.glxContextTag = glx_make_current_reply.context_tag;
//     free(glx_make_current_reply);
// #elif defined(OS_APPLE_MACOS)
//     CGLSetCurrentContext(context.cglContext);
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     EGL(eglMakeCurrent(context.display, context.mainSurface, context.mainSurface, context.context));
// #endif
// }
//
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
//
// /*
// ================================================================================================================================
//
// GPU Window.
//
// ================================================================================================================================
// */

// #elif defined(OS_LINUX_WAYLAND)
//
// #ifdef __GNUC__
// #pragma GCC diagnostic push
// #pragma GCC diagnostic ignored "-Wunused-parameter"
// #endif
// static void _keyboard_keymap_cb(void* data, struct wl_keyboard* keyboard, uint32_t format, int fd, uint32_t size) { close(fd); }
// static void _keyboard_modifiers_cb(void* data, struct wl_keyboard* keyboard, uint32_t serial, uint32_t mods_depressed,
//                                    uint32_t mods_latched, uint32_t mods_locked, uint32_t group) {}
//
// static void _keyboard_enter_cb(void* data, struct wl_keyboard* keyboard, uint32_t serial, struct wl_surface* surface,
//                                struct wl_array* keys) {}
//
// static void _keyboard_leave_cb(void* data, struct wl_keyboard* keyboard, uint32_t serial, struct wl_surface* surface) {}
//
// static void _pointer_leave_cb(void* data, struct wl_pointer* pointer, uint32_t serial, struct wl_surface* surface) {}
//
// static void _pointer_enter_cb(void* data, struct wl_pointer* pointer, uint32_t serial, struct wl_surface* surface, wl_fixed_t sx,
//                               wl_fixed_t sy) {
//     wl_pointer_set_cursor(pointer, serial, null, 0, 0);
// }
//
// static void _pointer_motion_cb(void* data, struct wl_pointer* pointer, uint32_t time, wl_fixed_t x, wl_fixed_t y) {
//     ksGpuWindow* window = (ksGpuWindow*)data;
//     window.input.mouseInputX[0] = wl_fixed_to_int(x);
//     window.input.mouseInputY[0] = wl_fixed_to_int(y);
// }
//
// static void _pointer_button_cb(void* data, struct wl_pointer* pointer, uint32_t serial, uint32_t time, uint32_t button,
//                                uint32_t state) {
//     ksGpuWindow* window = (ksGpuWindow*)data;
//
//     uint32_t button_id = 0;
//     switch (button) {
//         case BTN_LEFT:
//             button_id = 0;
//             break;
//         case BTN_MIDDLE:
//             button_id = 1;
//             break;
//         case BTN_RIGHT:
//             button_id = 2;
//             break;
//     }
//
//     window.input.mouseInput[button_id] = state;
// }
//
// static void _pointer_axis_cb(void* data, struct wl_pointer* pointer, uint32_t time, uint32_t axis, wl_fixed_t value) {}
//
// static void _keyboard_key_cb(void* data, struct wl_keyboard* keyboard, uint32_t serial, uint32_t time, uint32_t key,
//                              uint32_t state) {
//     ksGpuWindow* window = (ksGpuWindow*)data;
//     if (key == KEY_ESC) window.windowExit = true;
//
//     if (state) window.input.keyInput[key] = state;
// }
//
// const struct wl_pointer_listener pointer_listener = {
//     _pointer_enter_cb, _pointer_leave_cb, _pointer_motion_cb, _pointer_button_cb, _pointer_axis_cb,
// };
//
// const struct wl_keyboard_listener keyboard_listener = {
//     _keyboard_keymap_cb, _keyboard_enter_cb, _keyboard_leave_cb, _keyboard_key_cb, _keyboard_modifiers_cb,
// };

export fn _seat_capabilities_cb(data: ?*anyopaque, seat: ?*wl.wl_seat, caps: u32) void {
    _ = data;
    _ = seat;
    _ = caps;
    //     ksGpuWindow* window = (ksGpuWindow*)data;
    //     if ((caps & WL_SEAT_CAPABILITY_POINTER) && !window.pointer) {
    //         window.pointer = wl_seat_get_pointer(seat);
    //         wl_pointer_add_listener(window.pointer, &pointer_listener, window);
    //     } else if (!(caps & WL_SEAT_CAPABILITY_POINTER) && window.pointer) {
    //         wl_pointer_destroy(window.pointer);
    //         window.pointer = null;
    //     }
    //
    //     if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !window.keyboard) {
    //         window.keyboard = wl_seat_get_keyboard(seat);
    //         wl_keyboard_add_listener(window.keyboard, &keyboard_listener, window);
    //     } else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && window.keyboard) {
    //         wl_keyboard_destroy(window.keyboard);
    //         window.keyboard = null;
    //     }
}

const seat_listener: wl.wl_seat_listener = .{
    .capabilities = _seat_capabilities_cb,
};

// static void _xdg_surface_configure_cb(void* data, struct zxdg_surface_v6* surface, uint32_t serial) {
//     zxdg_surface_v6_ack_configure(surface, serial);
// }
//
// const struct zxdg_surface_v6_listener xdg_surface_listener = {
//     _xdg_surface_configure_cb,
// };
//
// static void _xdg_shell_ping_cb(void* data, struct zxdg_shell_v6* shell, uint32_t serial) { zxdg_shell_v6_pong(shell, serial); }
//
// const struct zxdg_shell_v6_listener xdg_shell_listener = {
//     _xdg_shell_ping_cb,
// };
//
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
//
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
    _ = instance;
    _ = queueIndex;
    _ = queueInfo;
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

    // ksGpuDevice_Create(&window.device, instance, queueInfo);
    //
    // ksGpuContext_CreateForSurface(&window.context, &window.device, window.display);
    //
    // ksGpuContext_SetCurrent(&window.context);

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
//
// typedef enum { MOUSE_LEFT = BTN_LEFT, MOUSE_MIDDLE = BTN_MIDDLE, MOUSE_RIGHT = BTN_RIGHT } ksMouseButton;

// Initialize the gl extensions. Note we have to open a window.
var m_window: ksGpuWindow = .{};
var m_driverInstance: ksDriverInstance = .{};
var m_queueInfo: ksGpuQueueInfo = .{};
var m_colorFormat: ksGpuSurfaceColorFormat = .B8G8R8A8;
var m_depthFormat: ksGpuSurfaceDepthFormat = .D24;
var m_sampleCount: ksGpuSampleCount = ._1;
var m_graphicsBinding: c.XrGraphicsBindingOpenGLWaylandKHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WAYLAND_KHR };

pub fn binding() *anyopaque {
    return &m_graphicsBinding;
}

// void gfxwrapper_opengl_deinit() {
//     //
//     ksGpuWindow_Destroy(&window);
// }

pub fn init() void {
    m_window = .{};
    m_driverInstance = (ksDriverInstance){};
    m_queueInfo = (ksGpuQueueInfo){};
    m_colorFormat = .B8G8R8A8;
    m_depthFormat = .D24;
    m_sampleCount = ._1;
    m_graphicsBinding = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WAYLAND_KHR };
    if (!ksGpuWindow_Create(&m_window, &m_driverInstance, &m_queueInfo, 0, m_colorFormat, m_depthFormat, m_sampleCount, 640, 480, false)) {
        @panic("Unable to create GL context");
    }

    // TODO: Just need something other than null here for now (for validation).  Eventually need
    //       to correctly put in a valid pointer to an wl_display
    // m_graphicsBinding.display = @ptrFromInt(0xFFFFFFFF);
}
