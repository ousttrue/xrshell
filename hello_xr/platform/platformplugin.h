#pragma once
#include <openxr/openxr.h>

#ifdef __cplusplus
extern "C" {
#endif

struct PlatformData {
    void* applicationVM;
    void* applicationActivity;
};

void XR_PLATFORM_init(struct Options* options, struct PlatformData* data);
void XR_PLATFORM_deinit();

// Provide extension to XrInstanceCreateInfo for xrCreateInstance.
XrBaseInStructure* XR_PLATFORM_GetInstanceCreateExtension();

// OpenXR instance-level extensions required by this platform.
const char** XR_PLATFORM_GetInstanceExtensions(size_t* n);

// Perform required steps after updating Options
void XR_PLATFORM_UpdateOptions(struct Options* options);

#ifdef __cplusplus
}
#endif
