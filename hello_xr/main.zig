const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const xrs = @import("xrshell/xrshell.zig");
const XrError = xrs.XrError;
const XrResult = xrs.XrResult;
const OpenXrProgram = @import("OpenXrProgram.zig");
const action = @import("action.zig");
const Options = @import("Options.zig");
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");
const gfx = if (builtin.os.tag == .windows)
    @import("gfx/graphicsplugin_opengl.zig")
else
    @import("gfx/graphicsplugin_opengles.zig");
const geometry = @import("geometry.zig");

pub const std_options: std.Options = .{
    .logFn = console_color_logger.logFn,
    .log_level = .debug,
};

pub fn main() !void {
    // const allocator = std.heap.c_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var options: Options = .{};
    if (!options.UpdateOptionsFromCommandLine(std.os.argv)) {
        return;
    }

    // Spawn a thread to wait for a keypress
    var quit_key: QuitKeyObserver = .{};
    try quit_key.spawn();
    defer quit_key.deinit();

    while (!quit_key.quitKeyPressed) {
        var instance = try xrs.Instance.init(allocator, .{
            .gfx_extensions = gfx.GetInstanceExtensions(),
            .form_factor = options.parsed.FormFactor,
        });
        defer instance.deinit();

        try gfx.InitializeDevice(instance.instance, instance.systemId);

        var session = try xrs.Session.init(
            instance.instance,
            instance.systemId,
            gfx.GetGraphicsBinding(),
        );
        defer session.deinit();
        var isSessionRunning = false;

        var prog = OpenXrProgram.init(
            allocator,
            instance.instance,
            instance.systemId,
            session.session,
            &options,
        );
        defer prog.deinit();

        try prog.LogViewConfigurations();

        try prog.LogReferenceSpaces();
        try action.InitializeActions(prog.instance, prog.session);
        try prog.CreateVisualizedSpaces();

        {
            const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(prog.options.AppSpace.span());
            _ = try XrResult.init(c.xrCreateReferenceSpace(prog.session, &referenceSpaceCreateInfo, &prog.appSpace));
        }

        try prog.CreateSwapchains();

        while (!quit_key.quitKeyPressed) {
            switch (try instance.pollEvents()) {
                .quit => {
                    break;
                },
                .restart => {
                    continue;
                },
                .next => {
                    if (isSessionRunning) {
                        try prog.run_frame();
                    } else {
                        // Throttle loop since xrWaitFrame won't be called.
                        std.Thread.sleep(std.time.ns_per_ms * 250);
                    }
                },
                .session_begin => {
                    try session.begin(options.parsed.ViewConfigType);
                    isSessionRunning = true;
                },
                .session_end => {
                    try session.end();
                    isSessionRunning = false;
                },
            }
        }
    }
}
