#pragma once
#include <openxr/openxr.h>
#include <set>
#include <map>
#include <vector>
#include <array>

struct Swapchain {
    XrSwapchain handle;
    int32_t width;
    int32_t height;
};

namespace Side {
const int LEFT = 0;
const int RIGHT = 1;
const int COUNT = 2;
}  // namespace Side

struct InputState {
    XrActionSet actionSet{XR_NULL_HANDLE};
    XrAction grabAction{XR_NULL_HANDLE};
    XrAction poseAction{XR_NULL_HANDLE};
    XrAction vibrateAction{XR_NULL_HANDLE};
    XrAction quitAction{XR_NULL_HANDLE};
    std::array<XrPath, Side::COUNT> handSubactionPath;
    std::array<XrSpace, Side::COUNT> handSpace;
    std::array<float, Side::COUNT> handScale = {{1.0f, 1.0f}};
    std::array<XrBool32, Side::COUNT> handActive;
};

class OpenXrProgram {
    const Options& m_options;
    struct IPlatformPlugin* m_platformPlugin;
    struct IGraphicsPlugin* m_graphicsPlugin;
    XrInstance m_instance{XR_NULL_HANDLE};
    XrSession m_session{XR_NULL_HANDLE};
    XrSpace m_appSpace{XR_NULL_HANDLE};
    XrSystemId m_systemId{XR_NULL_SYSTEM_ID};

    std::vector<XrViewConfigurationView> m_configViews;
    std::vector<Swapchain> m_swapchains;
    std::map<XrSwapchain, std::vector<XrSwapchainImageBaseHeader*>> m_swapchainImages;
    std::vector<XrView> m_views;
    int64_t m_colorSwapchainFormat{-1};

    std::vector<XrSpace> m_visualizedSpaces;

    // Application's current lifecycle state according to the runtime
    XrSessionState m_sessionState{XR_SESSION_STATE_UNKNOWN};
    bool m_sessionRunning{false};

    XrEventDataBuffer m_eventDataBuffer;
    InputState m_input;

    const std::set<XrEnvironmentBlendMode> m_acceptableBlendModes;

   public:
    OpenXrProgram(const struct Options& options, struct IPlatformPlugin* platformPlugin, struct IGraphicsPlugin* graphicsPlugin);
    ~OpenXrProgram();

    // Create an Instance and other basic instance-level initialization.
    void CreateInstance();
    // Select a System for the view configuration specified in the Options
    void InitializeSystem();
    // Initialize the graphics device for the selected system.
    void InitializeDevice();
    // Create a Session and other basic session-level initialization.
    void InitializeSession();
    // Create a Swapchain which requires coordinating with the graphics plugin to select the format, getting the system graphics
    // properties, getting the view configuration and grabbing the resulting swapchain images.
    void CreateSwapchains();
    // Process any events in the event queue.
    void PollEvents(bool* exitRenderLoop, bool* requestRestart);
    // Manage session lifecycle to track if RenderFrame should be called.
    bool IsSessionRunning() const;
    // Manage session state to track if input should be processed.
    bool IsSessionFocused() const;
    // Sample input actions and generate haptic feedback.
    void PollActions();
    // Create and submit a frame.
    void RenderFrame();
    // Get preferred blend mode based on the view configuration specified in the Options
    XrEnvironmentBlendMode GetPreferredBlendMode() const;

   private:
    void CreateInstanceInternal();
    void CreateVisualizedSpaces();
    void InitializeActions();
    void LogInstanceInfo();
    void LogViewConfigurations();
    void LogEnvironmentBlendMode(XrViewConfigurationType type);
    void LogReferenceSpaces();
    const XrEventDataBaseHeader* TryReadNextEvent();
    void HandleSessionStateChangedEvent(const XrEventDataSessionStateChanged& stateChangedEvent, bool* exitRenderLoop,
                                        bool* requestRestart);
    void LogActionSourceName(XrAction action, const std::string& actionName) const;
    bool RenderLayer(XrTime predictedDisplayTime, std::vector<XrCompositionLayerProjectionView>& projectionLayerViews,
                     XrCompositionLayerProjection& layer);
};
