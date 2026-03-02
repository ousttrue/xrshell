pub const openxr = @cImport({
    @cInclude("openxr/openxr.h");
    @cDefine("XR_USE_GRAPHICS_API_OPENGL", "1");
    @cInclude("openxr/openxr_platform.h");
    @cInclude("gfx/gfxwrapper_opengl.h");
});
