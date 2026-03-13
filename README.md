# xrshell

`zig-0.15.2`

`OpenXR-1.0,57`

| env                | triple                | runtime        | extension               | binding                             |
| ------------------ | --------------------- | -------------- | ----------------------- | ----------------------------------- |
| wayland + OpenGLES | x86_64-linux-gnu      | WiVRn-26.2.3   | XR_MNDX_egl_enable      | XrGraphicsBindingEGLMNDX            |
| windows + OpenGL   | x86_64-windows-gnu    | Oculus-1.117.0 | XR_KHR_opengl_enable    | XrGraphicsBindingOpenGLWin32KHR     |
| android + OpenGLES | aarch64-linux-android | Oculus(Quest3) | XR_KHR_opengl_es_enable | XrGraphicsBindingOpenGLESAndroidKHR |

use

[sokol-zig](https://github.com/floooh/sokol-zig)
