pub const openxr = @cImport({
    @cInclude("openxr/openxr.h");
    @cDefine("XR_USE_PLATFORM_WAYLAND", "1");
    @cDefine("XR_USE_GRAPHICS_API_OPENGL", "1");
    @cInclude("openxr/openxr_platform.h");
    @cInclude("glad/gl.h");
    @cInclude("linux/input.h");
});
