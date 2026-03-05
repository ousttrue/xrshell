const builtin = @import("builtin");
pub const Options = @import("Options.zig");
pub const geometry = @import("geometry.zig");
pub const xr_result = @import("xr_result.zig");
pub const xr_util = @import("xr_util.zig");
pub const Cube = @import("Cube.zig");

pub const gfx = if (builtin.target.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");

pub const platform = if (builtin.target.os.tag == .windows)
    @import("platform/platformplugin_win32.zig")
else
    @import("platform/platformplugin_posix.zig");
