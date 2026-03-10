const std = @import("std");
const c = @import("c");

const OPENGL_VERSION_MAJOR = 4;
const OPENGL_VERSION_MINOR = 3;

fn BIT(x: usize) u32 {
    return 1 << x;
}

const APPLICATION_NAME = "OpenGL SI";
const WINDOW_TITLE = "OpenGL SI";

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
    hDC: c.HDC = null,
    hGLRC: c.HGLRC = null,

    fn init(
        colorFormat: ksGpuSurfaceColorFormat,
        depthFormat: ksGpuSurfaceDepthFormat,
        sampleCount: ksGpuSampleCount,
        hInstance: c.HINSTANCE,
        hDC: c.HDC,
    ) @This() {
        const bits: ksGpuSurfaceBits = .fromSurfaceFormat(colorFormat, depthFormat);

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
            @panic("Failed to find a suitable pixel format.");
        }

        if (0 == c.SetPixelFormat(localDC, pixelFormat, &pfd)) {
            @panic("Failed to set the pixel format.");
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
                @panic("Failed to find MSAA pixel format.");
            }

            _ = c.memset(&pfd, 0, @sizeOf(@TypeOf(pfd)));

            if (0 == c.DescribePixelFormat(hDC, pixelFormat, @sizeOf(c.PIXELFORMATDESCRIPTOR), &pfd)) {
                @panic("Failed to describe the pixel format.");
            }

            if (0 == c.SetPixelFormat(hDC, pixelFormat, &pfd)) {
                @panic("Failed to set the pixel format.");
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

        const hGLRC = c.wglCreateContextAttribsARB(hDC, null, &contextAttribs);
        if (null == hGLRC) {
            @panic("Failed to create GL context.");
        }
        _ = c.wglMakeCurrent(hDC, hGLRC);

        return .{
            .hDC = hDC,
            .hGLRC = hGLRC,
        };
    }

    fn destroy(context: *ksGpuContext) void {
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

    fn setCurrent(context: *ksGpuContext) void {
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

};

const ksGpuSurfaceBits = struct {
    redBits: u8,
    greenBits: u8,
    blueBits: u8,
    alphaBits: u8,
    colorBits: u8,
    depthBits: u8,

    fn fromSurfaceFormat(colorFormat: ksGpuSurfaceColorFormat, depthFormat: ksGpuSurfaceDepthFormat) ksGpuSurfaceBits {
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
};

const ksGpuWindowEvent = enum { NONE, ACTIVATED, DEACTIVATED, EXIT };

const ksGpuWindowInput = struct {
    keyInput: [256]bool = undefined,
    mouseInput: [8]bool = undefined,
    mouseInputX: [8]c_int = undefined,
    mouseInputY: [8]c_int = undefined,
};

const ksGpuWindow = struct {
    context: ksGpuContext = .{},
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
    input: ksGpuWindowInput = .{},

    hInstance: c.HINSTANCE = null,
    hDC: c.HDC = null,
    hWnd: c.HWND = null,
    windowActiveState: bool,

    fn init(
        colorFormat: ksGpuSurfaceColorFormat,
        depthFormat: ksGpuSurfaceDepthFormat,
        sampleCount: ksGpuSampleCount,
        width: c_int,
        height: c_int,
        fullscreen: bool,
    ) @This() {
        return .{
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
            .windowActiveState = false,
        };
    }

    pub fn create(window: *@This()) bool {
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
            .right = window.windowWidth,
            .top = 0,
            .bottom = window.windowHeight,
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
            window.destroy();
            std.log.err("Failed to create window.", .{});
            return false;
        }

        _ = c.SetWindowLongPtrA(window.hWnd, c.GWLP_USERDATA, @intCast(@intFromPtr(window)));

        window.hDC = c.GetDC(window.hWnd);
        if (window.hDC == null) {
            window.destroy();
            std.log.err("Failed to acquire device context.", .{});
            return false;
        }

        window.context = .init(window.colorFormat, window.depthFormat, window.sampleCount, window.hInstance, window.hDC);
        window.context.setCurrent();

        _ = c.gladLoaderLoadGL();

        _ = c.ShowWindow(window.hWnd, c.SW_SHOW);
        _ = c.SetForegroundWindow(window.hWnd);
        _ = c.SetFocus(window.hWnd);

        return true;
    }

    fn destroy(window: *ksGpuWindow) void {
        window.context.destroy();

        //     if (window.windowFullscreen) {
        //         ChangeDisplaySettingsA(null, 0);
        //         ShowCursor(TRUE);
        //     }

        //     if (window.hDC) {
        //         if (!ReleaseDC(window.hWnd, window.hDC)) {
        //             Error("Failed to release device context.");
        //         }
        //         window.hDC = null;
        //     }

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
};

// Initialize the gl extensions. Note we have to open a window.
var m_window: ksGpuWindow = undefined;
var m_graphicsBinding: c.XrGraphicsBindingOpenGLWin32KHR = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR };

pub fn binding() *anyopaque {
    return &m_graphicsBinding;
}

pub fn init() void {
    const m_colorFormat: ksGpuSurfaceColorFormat = .B8G8R8A8;
    const m_depthFormat: ksGpuSurfaceDepthFormat = .D24;
    const m_sampleCount: ksGpuSampleCount = ._1;
    // m_colorFormat = .B8G8R8A8;
    // m_depthFormat = .D24;
    // m_sampleCount = ._1;
    m_graphicsBinding = .{ .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR };
    m_window = .init(m_colorFormat, m_depthFormat, m_sampleCount, 640, 480, false);
    if (!m_window.create()) {
        @panic("Unable to create GL context");
    }

    m_graphicsBinding.hDC = m_window.context.hDC;
    m_graphicsBinding.hGLRC = m_window.context.hGLRC;
}
