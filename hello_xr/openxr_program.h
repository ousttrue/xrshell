#pragma once
#include <openxr/openxr.h>

#ifdef __cplusplus
extern "C" {
#endif

void XR_PROG_OpenXrProgram_init(struct Options* options);
void XR_PROG_OpenXrProgram_deinit();

// Create an Instance and other basic instance-level initialization.
void XR_PROG_CreateInstance();
// Select a System for the view configuration specified in the Options
void XR_PROG_InitializeSystem();
// Initialize the graphics device for the selected system.
void XR_PROG_InitializeDevice();
// Create a Session and other basic session-level initialization.
void XR_PROG_InitializeSession();
// Create a Swapchain which requires coordinating with the graphics plugin to select the format, getting the system graphics
// properties, getting the view configuration and grabbing the resulting swapchain images.
void XR_PROG_CreateSwapchains();
// Process any events in the event queue.
void XR_PROG_PollEvents(bool* exitRenderLoop, bool* requestRestart);
// Manage session lifecycle to track if RenderFrame should be called.
bool XR_PROG_IsSessionRunning();
// Manage session state to track if input should be processed.
bool XR_PROG_IsSessionFocused();
// Sample input actions and generate haptic feedback.
void XR_PROG_PollActions();
// Create and submit a frame.
void XR_PROG_RenderFrame();
// Get preferred blend mode based on the view configuration specified in the Options
XrEnvironmentBlendMode XR_PROG_GetPreferredBlendMode();

#ifdef __cplusplus
}
#endif
