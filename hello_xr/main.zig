const std = @import("std");
const c = @import("c");
const OpenXrProgram = @import("OpenXrProgram.zig");
const action = @import("action.zig");
const Options = @import("Options.zig");
const QuitKeyObserver = @import("QuitKeyObserver.zig");
const console_color_logger = @import("console_color_logger.zig");

pub const std_options: std.Options = .{
    .logFn = console_color_logger.logFn,
    .log_level = .debug,
};

var quit_key: QuitKeyObserver = .{};

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
    try quit_key.spawn();
    defer quit_key.deinit();

    while (!quit_key.quitKeyPressed) {
        const next = try run_instance(allocator, &options);
        if (!next) {
            break;
        }
    }
}

fn run_instance(allocator: std.mem.Allocator, options: *Options) !bool {
    OpenXrProgram.init(allocator, options);
    defer OpenXrProgram.deinit(allocator);

    try OpenXrProgram.CreateInstance(allocator, null);
    try OpenXrProgram.InitializeSystem();

    options.SetEnvironmentBlendMode(try OpenXrProgram.GetPreferredBlendMode(allocator));

    try OpenXrProgram.InitializeDevice(allocator);
    const session = try OpenXrProgram.InitializeSession(allocator);
    try OpenXrProgram.CreateSwapchains(allocator);

    while (!quit_key.quitKeyPressed) {
        switch (try run_frame(allocator, session)) {
            .next => {},
            .quit => {
                return false;
            },
            .restart => {
                return true;
            },
        }
    }

    return false;
}

const NextFrame = enum {
    next,
    quit,
    restart,
};

fn run_frame(allocator: std.mem.Allocator, session: c.XrSession) !NextFrame {
    const next = try OpenXrProgram.PollEvents(allocator);
    switch (next) {
        .quit => {
            return .quit;
        },
        .restart => {
            return .restart;
        },
        .render => {},
    }

    if (OpenXrProgram.IsSessionRunning()) {
        try action.PollActions(session);
        // try OpenXrProgram.oRenderFrame(allocator);
        const frameState = try OpenXrProgram.beginFrame();
        var layer: ?*c.XrCompositionLayerBaseHeader = null;
        if (frameState.shouldRender == c.XR_TRUE) {
            if (try OpenXrProgram.locate(frameState.predictedDisplayTime)) {
                layer = try OpenXrProgram.RenderLayer(
                    allocator,
                    frameState.predictedDisplayTime,
                );
            }
        }
        try OpenXrProgram.endFrame(frameState.predictedDisplayTime, layer);
    } else {
        // Throttle loop since xrWaitFrame won't be called.
        std.Thread.sleep(std.time.ns_per_ms * 250);
    }
    return .next;
}
