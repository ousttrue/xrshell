const c = @import("c");

pub const extensions = [_][*:0]const u8{
    c.XR_KHR_OPENGL_ES_ENABLE_EXTENSION_NAME,
};

pub fn init() void {}

var m_graphicsBinding: c.XrGraphicsBindingOpenGLESAndroidKHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_ES_ANDROID_KHR, .next = null };

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
// bool ksGpuDevice_Create(ksGpuDevice *device, ksDriverInstance *instance, const ksGpuQueueInfo *queueInfo) {
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
//     device->instance = instance;
//     device->queueInfo = *queueInfo;
//
//     return true;
// }

// void ksGpuDevice_Destroy(ksGpuDevice *device) { memset(device, 0, sizeof(ksGpuDevice)); }

// ================================================================================================================================
// GPU Context.
// ================================================================================================================================

// static ksGpuSurfaceBits ksGpuContext_BitsForSurfaceFormat(const ksGpuSurfaceColorFormat colorFormat,
//                                                           const ksGpuSurfaceDepthFormat depthFormat) {
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

// void ksGpuContext_Destroy(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     if (context->ctx != EGL_NO_CONTEXT) {
//         EGL(eglDestroyContext(context->dpy, context->ctx));
//     }
//
//     if (context->dpy != EGL_NO_DISPLAY) {
//         EGL(eglTerminate(context->dpy));
//     }
//
//     context->dpy = EGL_NO_DISPLAY;
//     context->ctx = EGL_NO_CONTEXT;
//
// }

// void ksGpuContext_SetCurrent(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     EGL(eglMakeCurrent(context->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, context->ctx));
// }

// void ksGpuContext_UnsetCurrent(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     EGL(eglMakeCurrent(context->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT));
// }

// bool ksGpuContext_CheckCurrent(ksGpuContext *context) {
// #elif defined(OS_ANDROID) || defined(OS_LINUX_WAYLAND)
//     return (eglGetCurrentContext() == context->ctx);
// #else
// }

// ================================================================================================================================
// GPU Window.
// ================================================================================================================================

// #elif defined(OS_ANDROID)
//
// void ksGpuWindow_Destroy(ksGpuWindow *window) {
//     ksGpuContext_Destroy(&window->context);
//     ksGpuDevice_Destroy(&window->device);
// }
//
// bool ksGpuWindow_Create(ksGpuWindow *window, ksDriverInstance *instance, const ksGpuQueueInfo *queueInfo, const int queueIndex,
//                         const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                         const ksGpuSampleCount sampleCount, const int width, const int height, const bool fullscreen) {
// #ifdef XR_USE_PLATFORM_EGL
//     return ksGpuWindow_CreateEGL(window, instance, queueInfo, queueIndex, colorFormat, depthFormat, sampleCount, width, height,
//                                  fullscreen);
// #else
//     return false;
// #endif
// }
//
// #endif
//
// #ifdef XR_USE_PLATFORM_EGL
//
// static bool ksGpuContext_CreateForSurfaceEGL(ksGpuContext *context, const ksGpuDevice *device, const int queueIndex,
//                                              const ksGpuSurfaceColorFormat colorFormat, const ksGpuSurfaceDepthFormat depthFormat,
//                                              const ksGpuSampleCount sampleCount, EGLDisplay dpy) {
//     (void)sampleCount;
//     context->device = device;
//     context->dpy = dpy;
//
//     // clang-format off
//     EGLint glesContextAttribs[] = {
//         EGL_CONTEXT_CLIENT_VERSION, OPENGLES_VERSION_MAJOR,
//         EGL_CONTEXT_PRIORITY_LEVEL_IMG, EGL_CONTEXT_PRIORITY_MEDIUM_IMG,
//         EGL_NONE,
//     };
//     // clang-format on
//     // Use the default priority if KS_GPU_QUEUE_PRIORITY_MEDIUM is selected.
//     const ksGpuQueuePriority priority = device->queueInfo.queuePriorities[queueIndex];
//     if (priority != KS_GPU_QUEUE_PRIORITY_MEDIUM) {
//         glesContextAttribs[3] =
//             (priority == KS_GPU_QUEUE_PRIORITY_LOW) ? EGL_CONTEXT_PRIORITY_LOW_IMG : EGL_CONTEXT_PRIORITY_HIGH_IMG;
//     }
//
//     const ksGpuSurfaceBits bits = ksGpuContext_BitsForSurfaceFormat(colorFormat, depthFormat);
//
//     // clang-format off
//     const EGLint configAttribs[] = {
//         EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
//         EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
//         EGL_RED_SIZE, bits.redBits,
//         EGL_GREEN_SIZE, bits.greenBits,
//         EGL_BLUE_SIZE, bits.blueBits,
//         EGL_ALPHA_SIZE, bits.alphaBits,
//         EGL_NONE,
//     };
//     // clang-format on
//
//     EGLConfig config = 0;
//     EGLint numConfigs;
//     EGL(eglChooseConfig(context->dpy, configAttribs, &config, 1, &numConfigs));
//
//     context->ctx = eglCreateContext(context->dpy, config, EGL_NO_CONTEXT, glesContextAttribs);
//     if (context->ctx == EGL_NO_CONTEXT) {
//         Error("eglCreateContext() failed: %s", EglErrorString(eglGetError()));
//         return false;
//     }
//
//     EGL(eglBindAPI(EGL_OPENGL_ES_API));
//
//     return true;
// }
//
// bool ksGpuWindow_CreateEGL(ksGpuWindow *window, ksDriverInstance *instance, const ksGpuQueueInfo *queueInfo, int queueIndex,
//                            ksGpuSurfaceColorFormat colorFormat, ksGpuSurfaceDepthFormat depthFormat, ksGpuSampleCount sampleCount,
//                            int width, int height, bool fullscreen) {
//     memset(window, 0, sizeof(ksGpuWindow));
//     (void)fullscreen;
//
//     window->colorFormat = colorFormat;
//     window->depthFormat = depthFormat;
//     window->sampleCount = sampleCount;
//     window->windowWidth = width;
//     window->windowHeight = height;
//     window->windowSwapInterval = 1;
//     window->windowRefreshRate = 60.0f;
//     window->windowFullscreen = true;
//     window->windowActive = false;
//     window->windowExit = false;
//
//     int eglVersion = gladLoaderLoadEGL(EGL_DEFAULT_DISPLAY);
//     if (!eglVersion) {
//         Error("Failed to load EGL");
//         return false;
//     }
//
//     printf("Loaded EGL %d.%d on first load\n", GLAD_VERSION_MAJOR(eglVersion), GLAD_VERSION_MINOR(eglVersion));
//
//     EGLDisplay dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
//     EGL(eglInitialize(dpy, NULL, NULL));
//
//     // need second load now that EGL is initialized - bootstrapping problem
//     eglVersion = gladLoaderLoadEGL(dpy);
//     if (!eglVersion) {
//         Error("Failed to reload EGL\n");
//         return false;
//     }
//
//     printf("Loaded EGL %d.%d after reload.\n", GLAD_VERSION_MAJOR(eglVersion), GLAD_VERSION_MINOR(eglVersion));
//
//     ksGpuDevice_Create(&window->device, instance, queueInfo);
//     ksGpuContext_CreateForSurfaceEGL(&window->context, &window->device, queueIndex, colorFormat, depthFormat, sampleCount, dpy);
//
//     ksGpuContext_SetCurrent(&window->context);
//
// #if defined(OS_ANDROID)
//     gladLoaderLoadGLES2();
// #else
//     return false;
// #endif
//     return true;
// }
//
// #endif
