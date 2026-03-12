const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const Window = @import("window/window.zig").Window;
const Renderer = @import("gfx/RendererOpenGL4.zig");
const App = @import("App.zig");

pub const std_options: std.Options = .{
    .logFn = console_color_logger.logFn,
    .log_level = .debug,
};

pub fn main() !void {
    var quit_key: QuitKeyObserver = .{};
    try quit_key.spawn();
    defer quit_key.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const options: xrs.Options = try .init(std.os.argv);

    const window = Window.create(allocator);
    defer window.destroy();

    var renderer = Renderer.init(allocator);
    defer renderer.deinit();

    while (!quit_key.quitKeyPressed) {
        std.log.warn("New instance", .{});

        var app: App = try .init(
            allocator,
            &gfx.extensions,
            null,
            options.FormFactor,
            options.ViewConfigType,
            gfx.makeBinding(window.context),
            options.AppSpace,
        );
        defer app.deinit();

        std.log.warn("Loop start", .{});
        while (!quit_key.quitKeyPressed) {
            const next = try app.run_frame(&renderer);
            switch (next) {
                .quit => break,
                .next => continue,
            }
        }
        break;
    }
}
