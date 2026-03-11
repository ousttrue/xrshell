const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const OpenXrProgram = @import("OpenXrProgram.zig");
const Options = @import("Options.zig");
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const geometry = @import("geometry.zig");
const Window = @import("window/window.zig").Window;

pub const std_options: std.Options = .{
    .logFn = console_color_logger.logFn,
    .log_level = .debug,
};

pub fn main() !void {
    // Spawn a thread to wait for a keypress
    var quit_key: QuitKeyObserver = .{};
    try quit_key.spawn();
    defer quit_key.deinit();

    // const allocator = std.heap.c_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const options: Options = try .init(std.os.argv);

    while (!quit_key.quitKeyPressed) {
        std.log.warn("New instance", .{});

        const next = try run_instance(
            allocator,
            &quit_key.quitKeyPressed,
            options.FormFactor,
            options.ViewConfigType,
            options.AppSpace,
        );
        switch (next) {
            .quit => break,
            .restart => continue,
        }
    }
}

fn run_instance(
    allocator: std.mem.Allocator,
    quit_key: *const bool,
    form_factor: c.XrFormFactor,
    view_config_type: c.XrViewConfigurationType,
    app_space: Options.ReferenceSpaceType,
) !enum {
    quit,
    restart,
} {
    var instance = try xrs.Instance.init(allocator, .{
        .gfx_extensions = gfx.GetInstanceExtensions(),
        .form_factor = form_factor,
    });
    defer instance.deinit();
    const blend_mode = try instance.getPreferredBlendMode(view_config_type);
    try instance.logViewConfigurations(view_config_type, blend_mode);

    const window = Window.create(allocator);
    defer window.destroy();

    var binding: c.XrGraphicsBindingOpenGLWin32KHR = .{
        .type = c.XR_TYPE_GRAPHICS_BINDING_OPENGL_WIN32_KHR,
        .hDC = window.context.hDC,
        .hGLRC = window.context.hGLRC,
    };

    gfx.init(allocator);
    try gfx.InitializeDevice(instance.instance, instance.systemId);
    defer gfx.deinit(allocator);

    var session = try xrs.Session.init(
        allocator,
        instance.instance,
        instance.systemId,
        @ptrCast(&binding),
    );
    defer session.deinit();

    var action = try xrs.Action.init(allocator, instance.instance, session.session);
    defer action.deinit();

    var prog = try OpenXrProgram.init(
        allocator,
        instance.instance,
        instance.systemId,
        session.session,
        view_config_type,
        app_space,
    );
    defer prog.deinit();

    var isSessionRunning = false;
    std.log.warn("Loop start", .{});
    while (!quit_key.*) {
        switch (try instance.pollEvents()) {
            .quit => {
                break;
            },
            .restart => {
                return .restart;
            },
            .next => {
                if (isSessionRunning) {
                    try action.pollActions();

                    const frameState = try prog.beginFrame();
                    var layer: ?*c.XrCompositionLayerBaseHeader = null;
                    if (frameState.shouldRender == c.XR_TRUE) {
                        if (try prog.locate(frameState.predictedDisplayTime, view_config_type)) {
                            const cubes = try action.update(prog.appSpace, frameState.predictedDisplayTime);
                            layer = try prog.renderLayer(
                                blend_mode,
                                cubes,
                            );
                        }
                    }
                    try prog.endFrame(frameState.predictedDisplayTime, blend_mode, layer);
                } else {
                    // Throttle loop since xrWaitFrame won't be called.
                    std.Thread.sleep(std.time.ns_per_ms * 250);
                }
            },
            .session_begin => {
                try session.begin(view_config_type);
                isSessionRunning = true;
            },
            .session_end => {
                try session.end();
                isSessionRunning = false;
            },
        }
    }

    return .quit;
}
