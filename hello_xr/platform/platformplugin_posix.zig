const c = @import("../c.zig").openxr;
// #include "platformplugin.h"
// #include "common.h"
//
// // Create a platform plugin for the platform specified at compile time.
// void XR_PLATFORM_init(struct Options* options, struct PlatformData* data) { Log::Write(Log::Level::Info, "PLATFORM => POSIX"); }
// void XR_PLATFORM_deinit() {}

// OpenXR instance-level extensions required by this platform.
pub fn GetInstanceExtensions() [][*:0]const u8 {
    return &.{};
}

// // Perform required steps after updating Options
// void XR_PLATFORM_UpdateOptions(struct Options* options) {}

// Provide extension to XrInstanceCreateInfo for xrCreateInstance.
pub fn GetInstanceCreateExtension() ?*c.XrBaseInStructure {
    return null;
}
