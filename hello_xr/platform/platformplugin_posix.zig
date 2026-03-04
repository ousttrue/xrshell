const c = @import("c");

pub fn init() void {
    // Log::Write(Log::Level::Info, "PLATFORM => POSIX");
}

pub fn deinit() void {}

// OpenXR instance-level extensions required by this platform.
pub fn GetInstanceExtensions() [][*:0]const u8 {
    return &.{};
}

// Provide extension to XrInstanceCreateInfo for xrCreateInstance.
pub fn GetInstanceCreateExtension() ?*c.XrBaseInStructure {
    return null;
}
