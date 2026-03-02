#pragma once
#include <openxr/openxr.h>

#ifdef __cplusplus
extern "C" {
#endif

struct Cube {
    XrPosef Pose;
    XrVector3f Scale;
};

void XR_GFX_init(const struct Options* options);
void XR_GFX_deinit();

// OpenXR extensions required by this graphics API.
const char** XR_GFX_GetInstanceExtensions(size_t* n);

// Create an instance of this graphics api for the provided instance and systemId.
void XR_GFX_InitializeDevice(XrInstance instance, XrSystemId systemId);

// Select the preferred swapchain format from the list of available formats.
int64_t XR_GFX_SelectColorSwapchainFormat(const int64_t* runtimeFormats, size_t n);

// Get the graphics binding header for session creation.
const XrBaseInStructure* XR_GFX_GetGraphicsBinding();

// Allocate space for the swapchain image structures. These are different for each graphics API. The returned
// pointers are valid for the lifetime of the graphics plugin.
void XR_GFX_AllocateSwapchainImageStructs(uint32_t capacity, const XrSwapchainCreateInfo& swapchainCreateInfo,
                                          XrSwapchainImageBaseHeader** out);

// Render to a swapchain image for a projection view.
void XR_GFX_RenderView(const XrCompositionLayerProjectionView* layerView, const XrSwapchainImageBaseHeader* swapchainImage,
                       int64_t swapchainFormat, const Cube* cubes, size_t cubeCount);

// Get recommended number of sub-data element samples in view (recommendedSwapchainSampleCount)
// if supported by the graphics plugin. A supported value otherwise.
uint32_t XR_GFX_GetSupportedSwapchainSampleCount(const XrViewConfigurationView* view);
//     return view.recommendedSwapchainSampleCount;
// }

// Perform required steps after updating Options
void XR_GFX_UpdateOptions(const struct Options* options);

#ifdef __cplusplus
}
#endif
