const std = @import("std");
const c = @import("c");
const AppSpaceType = @import("xr_types.zig").AppSpaceType;

FormFactor: c.XrFormFactor = c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY,
ViewConfigType: c.XrViewConfigurationType = c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO,
AppSpace: AppSpaceType = .Local,

pub fn init(argv: [][*:0]u8) !@This() {
    var this: @This() = .{};

    var i: usize = 1;
    while (i < argv.len) {
        const arg = getNextArg(argv, &i);
        if (std.ascii.eqlIgnoreCase(arg, "--formfactor") or std.ascii.eqlIgnoreCase(arg, "-ff")) {
            this.FormFactor = try GetXrFormFactor(getNextArg(argv, &i));
        } else if (std.ascii.eqlIgnoreCase(arg, "--viewconfig") or std.ascii.eqlIgnoreCase(arg, "-vc")) {
            this.ViewConfigType = try GetXrViewConfigurationType(getNextArg(argv, &i));
        } else if (std.ascii.eqlIgnoreCase(arg, "--space") or std.ascii.eqlIgnoreCase(arg, "-s")) {
            const val = getNextArg(argv, &i);
            inline for (@typeInfo(AppSpaceType).@"enum".fields) |f| {
                if (std.ascii.eqlIgnoreCase(f.name, val)) {
                    this.AppSpace = @enumFromInt(f.value);
                }
            }
        } else if (std.ascii.eqlIgnoreCase(arg, "--verbose") or std.ascii.eqlIgnoreCase(arg, "-v")) {
            // Log::SetLevel(Log::Level::Verbose);
        } else if (std.ascii.eqlIgnoreCase(arg, "--help") or std.ascii.eqlIgnoreCase(arg, "-h")) {
            ShowHelp();
            return error.help;
        } else {
            std.log.err("Unknown argument: {s}", .{arg});
            unreachable;
        }
    }

    return this;
}

fn getNextArg(argv: [][*:0]u8, i: *usize) []const u8 {
    if (i.* >= argv.len) {
        @panic("Argument parameter missing");
    }
    defer i.* += 1;
    return std.mem.span(argv[i.*]);
}

pub fn GetXrFormFactor(formFactorStr: []const u8) !c.XrFormFactor {
    if (std.ascii.eqlIgnoreCase(formFactorStr, "Hmd")) {
        return c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;
    }
    if (std.ascii.eqlIgnoreCase(formFactorStr, "Handheld")) {
        return c.XR_FORM_FACTOR_HANDHELD_DISPLAY;
    }
    std.log.err("Unknown form factor '{s}'", .{formFactorStr});
    return error.GetXrFormFactor;
}

pub fn GetXrViewConfigurationType(viewConfigurationStr: []const u8) !c.XrViewConfigurationType {
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr, "Mono")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_MONO;
    }
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr, "Stereo")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO;
    }
    std.log.err("Unknown view configuration '{s}'", .{viewConfigurationStr});
    return error.GetXrViewConfigurationType;
}

fn GetXrEnvironmentBlendMode(environmentBlendModeStr: []const u8) !c.XrEnvironmentBlendMode {
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "Opaque")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "Additive")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "AlphaBlend")) {
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
    std.log.info("HelloXr [--formfactor|-ff <Form factor>] [--viewconfig|-vc <View config>] " ++
        "[--blendmode|-bm <Blend mode>] [--space|-s <Space>] [--verbose|-v]", .{});
    std.log.info("Form factors:             Hmd, Handheld", .{});
    std.log.info("View configurations:      Mono, Stereo", .{});
    std.log.info("Environment blend modes:  Opaque, Additive, AlphaBlend", .{});
    std.log.info("Spaces:                   View, Local, Stage", .{});
}
