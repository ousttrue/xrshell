const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");
const binding = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig").binding;
const Window = @import("window/window.zig").Window;
const App = @import("App.zig");
const Renderer = @import("gfx/OpenGLRenderer.zig");
const shaders = @import("gfx/shaders.zig");

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

    var renderer = Renderer.init(allocator, shaders.gl4.vs, shaders.gl4.fs);
    defer renderer.deinit();

    while (!quit_key.quitKeyPressed) {
        std.log.warn("New instance", .{});

        var app: App = try .init(
            allocator,
            &binding.extensions,
            &binding.requirements,
            null,
            options.FormFactor,
            options.ViewConfigType,
            @ptrCast(&binding.makeBinding(window.context)),
        );
        defer app.deinit();

        var action = try xrs.Action.init(allocator, app.instance.instance, app.session.session);
        defer action.deinit();

        var stereo_view = try xrs.StereoView.init(
            allocator,
            app.instance.instance,
            app.instance.systemId,
            app.session.session,
            app.session.swapchainFormats,
            c.GL_DEPTH_COMPONENT32,
            binding.getSupportedSwapchainSampleCount(),
            options.ViewConfigType,
            options.AppSpace,
        );
        defer stereo_view.deinit();

        std.log.warn("Loop start", .{});
        while (!quit_key.quitKeyPressed) {
            const next = try app.run_frame();
            switch (next) {
                .quit => break,
                .next => continue,
                .restart => {},
                .render => {
                    // begin frame
                    const frameState = try stereo_view.beginFrame();

                    // scene
                    try action.pollActions();
                    const cubes = try action.update(stereo_view.space, frameState.predictedDisplayTime);

                    var layer_projection = try stereo_view.renderProjectionLayer(
                        frameState,
                        &renderer,
                        .OPENGL,
                        cubes,
                    );

                    // composition !
                    try stereo_view.endFrame(
                        frameState.predictedDisplayTime,
                        stereo_view.blend_mode,
                        if (layer_projection) |*l|
                            @ptrCast(l)
                        else
                            null,
                    );
                },
            }
        }
        break;
    }
}
