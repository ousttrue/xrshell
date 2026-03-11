const builtin = @import("builtin");

pub const Window = if (builtin.os.tag == .windows)
    @import("WindowWin32OpenGL.zig")
else
    @import("WindowWaylandOpenGLES.zig");
