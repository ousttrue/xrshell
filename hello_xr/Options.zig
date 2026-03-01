const std = @import("std");
const c = @cImport({
    @cInclude("openxr/openxr.h");
});

export fn GetXrFormFactor(_formFactorStr: [*c]const u8) c.XrFormFactor {
    const formFactorStr = std.mem.span(_formFactorStr);
    if (std.ascii.eqlIgnoreCase(formFactorStr, "Hmd")) {
        return c.XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY;
    }
    if (std.ascii.eqlIgnoreCase(formFactorStr, "Handheld")) {
        return c.XR_FORM_FACTOR_HANDHELD_DISPLAY;
    }
    std.log.err("Unknown form factor '{s}'", .{formFactorStr});
    unreachable;
}

export fn GetXrViewConfigurationType(_viewConfigurationStr: [*c]const u8) c.XrViewConfigurationType {
    const viewConfigurationStr = std.mem.span(_viewConfigurationStr);
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr, "Mono")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_MONO;
    }
    if (std.ascii.eqlIgnoreCase(viewConfigurationStr, "Stereo")) {
        return c.XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO;
    }
    std.log.err("Unknown view configuration '{s}'", .{viewConfigurationStr});
    unreachable;
}

export fn GetXrEnvironmentBlendMode(_environmentBlendModeStr: [*c]const u8) c.XrEnvironmentBlendMode {
    const environmentBlendModeStr = std.mem.span(_environmentBlendModeStr);
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "Opaque")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "Additive")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE;
    }
    if (std.ascii.eqlIgnoreCase(environmentBlendModeStr, "AlphaBlend")) {
        return c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND;
    }
    std.log.err("Unknown environment blend mode '{s}'", .{environmentBlendModeStr});
    unreachable;
}

export fn GetXrEnvironmentBlendModeStr(environmentBlendMode: c.XrEnvironmentBlendMode) [*c]const u8 {
    return switch (environmentBlendMode) {
        c.XR_ENVIRONMENT_BLEND_MODE_OPAQUE => "Opaque",
        c.XR_ENVIRONMENT_BLEND_MODE_ADDITIVE => "Additive",
        c.XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND => "AlphaBlend",
        else => {
            std.log.err("Unknown environment blend mode '{}'", .{environmentBlendMode});
            unreachable;
        },
    };
}
