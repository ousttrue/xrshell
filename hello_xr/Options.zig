const std = @import("std");
const c = @import("c");
const Options = @This();
const Parsed = extern struct {
    FormFactor: c.XrFormFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY,
    ViewConfigType: c.XrViewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
    // EnvironmentBlendMode: c.XrEnvironmentBlendMode = c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE,
};

GraphicsPlugin: FixedString = .init(""),
FormFactor: FixedString = .init("Hmd"),
ViewConfiguration: FixedString = .init("Stereo"),
// EnvironmentBlendMode: FixedString = .init("Opaque"),
AppSpace: FixedString = .init("Local"),
parsed: Parsed = .{},

pub fn GetBackgroundClearColor(environmentBlendMode: c.XrEnvironmentBlendMode) [4]f32 {
    const SlateGrey = [4]f32{ 0.184313729, 0.309803933, 0.309803933, 1.0 };
    const TransparentBlack = [4]f32{ 0.0, 0.0, 0.0, 0.0 };
    const Black = [4]f32{ 0.0, 0.0, 0.0, 1.0 };
    return switch (environmentBlendMode) {
        c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE => SlateGrey,
        c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE => Black,
        c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND => TransparentBlack,
        else => SlateGrey,
    };
}

pub fn ParseStrings(this: *@This()) !void {
    this.parsed.FormFactor = try GetXrFormFactor(this.FormFactor);
    this.parsed.ViewConfigType = try GetXrViewConfigurationType(this.ViewConfiguration);
    // this.parsed.EnvironmentBlendMode = try GetXrEnvironmentBlendMode(this.EnvironmentBlendMode);
}

fn GetXrFormFactor(formFactorStr: FixedString) !c.XrFormFactor {
    if (std.ascii.eqlIgnoreCase(formFactorStr.span(), "Hmd")) {
        return c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;
    }
    if (std.ascii.eqlIgnoreCase(formFactorStr.span(), "Handheld")) {
        return c.XR_FORM_FACTOR_HANDHELD_DISPLAY;
    }
    std.log.err("Unknown form factor '{s}'", .{formFactorStr.span()});
    return error.GetXrFormFactor;
}

fn GetXrViewConfigurationType(viewConfigurationStr: FixedString) !c.XrViewConfigurationType {
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr.span(), "Mono")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_MONO;
    }
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr.span(), "Stereo")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO;
    }
    std.log.err("Unknown view configuration '{s}'", .{viewConfigurationStr.span()});
    return error.GetXrViewConfigurationType;
}

fn GetXrEnvironmentBlendMode(environmentBlendModeStr: FixedString) !c.XrEnvironmentBlendMode {
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr.span(), "Opaque")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr.span(), "Additive")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr.span(), "AlphaBlend")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND;
    }
    std.log.err("Unknown environment blend mode '{s}'", .{environmentBlendModeStr.span()});
    return error.GetXrEnvironmentBlendMode;
}

pub const FixedString = extern struct {
    c_str: [32]u8 = undefined,

    pub fn init(src: []const u8) @This() {
        var this: @This() = undefined;
        std.mem.copyForwards(u8, &this.c_str, src);
        this.c_str[src.len] = 0;
        return this;
    }

    pub fn span(this: *const @This()) []const u8 {
        return std.mem.sliceTo(
            &this.c_str,
            0,
        );
    }
};

fn GetXrEnvironmentBlendModeStr(environmentBlendMode: c.XrEnvironmentBlendMode) FixedString {
    return switch (environmentBlendMode) {
        c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE => .init("Opaque"),
        c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE => .init("Additive"),
        c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND => .init("AlphaBlend"),
        else => {
            std.log.err("Unknown environment blend mode '{}'", .{environmentBlendMode});
            unreachable;
        },
    };
}

fn ShowHelp() void {
    // TODO: Improve/update when things are more settled.
    std.log.info("HelloXr --graphics|-g <Graphics API> [--formfactor|-ff <Form factor>] [--viewconfig|-vc <View config>] " ++
        "[--blendmode|-bm <Blend mode>] [--space|-s <Space>] [--verbose|-v]", .{});
    std.log.info("Graphics APIs:            D3D11, D3D12, OpenGLES, OpenGL, Vulkan2, Vulkan, Metal", .{});
    std.log.info("Form factors:             Hmd, Handheld", .{});
    std.log.info("View configurations:      Mono, Stereo", .{});
    std.log.info("Environment blend modes:  Opaque, Additive, AlphaBlend", .{});
    std.log.info("Spaces:                   View, Local, Stage", .{});
}

// pub fn SetEnvironmentBlendMode(this: *@This(), environmentBlendMode: c.XrEnvironmentBlendMode) void {
//     this.EnvironmentBlendMode = GetXrEnvironmentBlendModeStr(environmentBlendMode);
//     this.parsed.EnvironmentBlendMode = environmentBlendMode;
// }

const Parser = struct {
    options: *Options,
    argv: [][*:0]u8,
    // Index 0 is the program name and is skipped.
    i: usize = 1,

    fn getNextArg(this: *@This()) []const u8 {
        if (this.i >= this.argv.len) {
            @panic("Argument parameter missing");
        }
        defer this.i += 1;
        return std.mem.span(this.argv[this.i]);
    }

    fn parse(this: *@This()) void {
        while (this.i < this.argv.len) {
            const arg = this.getNextArg();
            if (std.ascii.eqlIgnoreCase(arg, "--graphics") or std.ascii.eqlIgnoreCase(arg, "-g")) {
                this.options.GraphicsPlugin = .init(this.getNextArg());
            } else if (std.ascii.eqlIgnoreCase(arg, "--formfactor") or std.ascii.eqlIgnoreCase(arg, "-ff")) {
                this.options.FormFactor = .init(this.getNextArg());
            } else if (std.ascii.eqlIgnoreCase(arg, "--viewconfig") or std.ascii.eqlIgnoreCase(arg, "-vc")) {
                this.options.ViewConfiguration = .init(this.getNextArg());
            } 
            // else if (std.ascii.eqlIgnoreCase(arg, "--blendmode") or std.ascii.eqlIgnoreCase(arg, "-bm")) {
            //     this.options.EnvironmentBlendMode = .init(this.getNextArg());
            // } 
            else if (std.ascii.eqlIgnoreCase(arg, "--space") or std.ascii.eqlIgnoreCase(arg, "-s")) {
                this.options.AppSpace = .init(this.getNextArg());
            } else if (std.ascii.eqlIgnoreCase(arg, "--verbose") or std.ascii.eqlIgnoreCase(arg, "-v")) {
                // Log::SetLevel(Log::Level::Verbose);
            } else if (std.ascii.eqlIgnoreCase(arg, "--help") or std.ascii.eqlIgnoreCase(arg, "-h")) {
                ShowHelp();
                return;
            } else {
                std.log.err("Unknown argument: {s}", .{arg});
                unreachable;
            }
        }
    }
};

pub fn UpdateOptionsFromCommandLine(this: *@This(), argv: [][*:0]u8) bool {
    var parser: Parser = .{
        .options = this,
        .argv = argv,
    };
    parser.parse();

    // Check for required parameters.
    if (this.GraphicsPlugin.c_str[0] == 0) {
        std.log.err("GraphicsPlugin parameter is required", .{});
        ShowHelp();
        return false;
    }

    if (this.ParseStrings()) {} else |e| {
        std.log.err("{s}", .{@errorName(e)});
        ShowHelp();
        return false;
    }

    return true;
}
