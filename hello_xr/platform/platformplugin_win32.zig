const c = @import("c");

pub fn init() void {
    // CHECK_HRCMD(CoInitializeEx(nullptr, COINIT_MULTITHREADED));
}

pub fn deinit() void {
    // CoUninitialize();
}

pub fn GetInstanceExtensions() [][*:0]const u8 {
    return &.{};
}

pub fn GetInstanceCreateExtension() ?*c.XrBaseInStructure {
    return null;
}
