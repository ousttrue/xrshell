const std = @import("std");
const c = @import("gfx/gfxwrapper_opengl_wayland.zig").c;

pub const Side = struct {
    const LEFT = 0;
    const RIGHT = 1;
    const COUNT = 2;
};

pub const InputState = struct {
    actionSet: c.XrActionSet = null,
    // XrAction grabAction{XR_NULL_HANDLE};
    // XrAction poseAction{XR_NULL_HANDLE};
    // XrAction vibrateAction{XR_NULL_HANDLE};
    // XrAction quitAction{XR_NULL_HANDLE};
    // std::array<XrPath, Side::COUNT> handSubactionPath;
    // std::array<XrSpace, Side::COUNT> handSpace;
    // std::array<float, Side::COUNT> handScale = {{1.0f, 1.0f}};
    handActive: [Side.COUNT]c.XrBool32 = undefined,
};

var m_input = InputState;

pub fn init() void {}

pub fn deinit() void {
    //     if (m_input.actionSet != XR_NULL_HANDLE) {
    //         for (auto hand : {Side::LEFT, Side::RIGHT}) {
    //             xrDestroySpace(m_input.handSpace[hand]);
    //         }
    //         xrDestroyActionSet(m_input.actionSet);
    //     }
}

// static void InitializeActions() {
//     // Create an action set.
//     {
//         XrActionSetCreateInfo actionSetInfo{XR_TYPE_ACTION_SET_CREATE_INFO};
//         strcpy_s(actionSetInfo.actionSetName, "gameplay");
//         strcpy_s(actionSetInfo.localizedActionSetName, "Gameplay");
//         actionSetInfo.priority = 0;
//         CHECK_XRCMD(xrCreateActionSet(m_instance, &actionSetInfo, &m_input.actionSet));
//     }
//
//     // Get the XrPath for the left and right hands - we will use them as subaction paths.
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left", &m_input.handSubactionPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right", &m_input.handSubactionPath[Side::RIGHT]));
//
//     // Create actions.
//     {
//         // Create an input action for grabbing objects with the left and right hands.
//         XrActionCreateInfo actionInfo{XR_TYPE_ACTION_CREATE_INFO};
//         actionInfo.actionType = XR_ACTION_TYPE_FLOAT_INPUT;
//         strcpy_s(actionInfo.actionName, "grab_object");
//         strcpy_s(actionInfo.localizedActionName, "Grab Object");
//         actionInfo.countSubactionPaths = uint32_t(m_input.handSubactionPath.size());
//         actionInfo.subactionPaths = m_input.handSubactionPath.data();
//         CHECK_XRCMD(xrCreateAction(m_input.actionSet, &actionInfo, &m_input.grabAction));
//
//         // Create an input action getting the left and right hand poses.
//         actionInfo.actionType = XR_ACTION_TYPE_POSE_INPUT;
//         strcpy_s(actionInfo.actionName, "hand_pose");
//         strcpy_s(actionInfo.localizedActionName, "Hand Pose");
//         actionInfo.countSubactionPaths = uint32_t(m_input.handSubactionPath.size());
//         actionInfo.subactionPaths = m_input.handSubactionPath.data();
//         CHECK_XRCMD(xrCreateAction(m_input.actionSet, &actionInfo, &m_input.poseAction));
//
//         // Create output actions for vibrating the left and right controller.
//         actionInfo.actionType = XR_ACTION_TYPE_VIBRATION_OUTPUT;
//         strcpy_s(actionInfo.actionName, "vibrate_hand");
//         strcpy_s(actionInfo.localizedActionName, "Vibrate Hand");
//         actionInfo.countSubactionPaths = uint32_t(m_input.handSubactionPath.size());
//         actionInfo.subactionPaths = m_input.handSubactionPath.data();
//         CHECK_XRCMD(xrCreateAction(m_input.actionSet, &actionInfo, &m_input.vibrateAction));
//
//         // Create input actions for quitting the session using the left and right controller.
//         // Since it doesn't matter which hand did this, we do not specify subaction paths for it.
//         // We will just suggest bindings for both hands, where possible.
//         actionInfo.actionType = XR_ACTION_TYPE_BOOLEAN_INPUT;
//         strcpy_s(actionInfo.actionName, "quit_session");
//         strcpy_s(actionInfo.localizedActionName, "Quit Session");
//         actionInfo.countSubactionPaths = 0;
//         actionInfo.subactionPaths = nullptr;
//         CHECK_XRCMD(xrCreateAction(m_input.actionSet, &actionInfo, &m_input.quitAction));
//     }
//
//     std::array<XrPath, Side::COUNT> selectPath;
//     std::array<XrPath, Side::COUNT> squeezeValuePath;
//     std::array<XrPath, Side::COUNT> squeezeForcePath;
//     std::array<XrPath, Side::COUNT> squeezeClickPath;
//     std::array<XrPath, Side::COUNT> posePath;
//     std::array<XrPath, Side::COUNT> hapticPath;
//     std::array<XrPath, Side::COUNT> menuClickPath;
//     std::array<XrPath, Side::COUNT> bClickPath;
//     std::array<XrPath, Side::COUNT> triggerValuePath;
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/select/click", &selectPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/select/click", &selectPath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/squeeze/value", &squeezeValuePath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/squeeze/value", &squeezeValuePath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/squeeze/force", &squeezeForcePath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/squeeze/force", &squeezeForcePath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/squeeze/click", &squeezeClickPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/squeeze/click", &squeezeClickPath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/grip/pose", &posePath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/grip/pose", &posePath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/output/haptic", &hapticPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/output/haptic", &hapticPath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/menu/click", &menuClickPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/menu/click", &menuClickPath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/b/click", &bClickPath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/b/click", &bClickPath[Side::RIGHT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/left/input/trigger/value", &triggerValuePath[Side::LEFT]));
//     CHECK_XRCMD(xrStringToPath(m_instance, "/user/hand/right/input/trigger/value", &triggerValuePath[Side::RIGHT]));
//     // Suggest bindings for KHR Simple.
//     {
//         XrPath khrSimpleInteractionProfilePath;
//         CHECK_XRCMD(xrStringToPath(m_instance, "/interaction_profiles/khr/simple_controller", &khrSimpleInteractionProfilePath));
//         std::vector<XrActionSuggestedBinding> bindings{{// Fall back to a click input for the grab action.
//                                                         {m_input.grabAction, selectPath[Side::LEFT]},
//                                                         {m_input.grabAction, selectPath[Side::RIGHT]},
//                                                         {m_input.poseAction, posePath[Side::LEFT]},
//                                                         {m_input.poseAction, posePath[Side::RIGHT]},
//                                                         {m_input.quitAction, menuClickPath[Side::LEFT]},
//                                                         {m_input.quitAction, menuClickPath[Side::RIGHT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::RIGHT]}}};
//         XrInteractionProfileSuggestedBinding suggestedBindings{XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
//         suggestedBindings.interactionProfile = khrSimpleInteractionProfilePath;
//         suggestedBindings.suggestedBindings = bindings.data();
//         suggestedBindings.countSuggestedBindings = (uint32_t)bindings.size();
//         CHECK_XRCMD(xrSuggestInteractionProfileBindings(m_instance, &suggestedBindings));
//     }
//     // Suggest bindings for the Oculus Touch.
//     {
//         XrPath oculusTouchInteractionProfilePath;
//         CHECK_XRCMD(
//             xrStringToPath(m_instance, "/interaction_profiles/oculus/touch_controller", &oculusTouchInteractionProfilePath));
//         std::vector<XrActionSuggestedBinding> bindings{{{m_input.grabAction, squeezeValuePath[Side::LEFT]},
//                                                         {m_input.grabAction, squeezeValuePath[Side::RIGHT]},
//                                                         {m_input.poseAction, posePath[Side::LEFT]},
//                                                         {m_input.poseAction, posePath[Side::RIGHT]},
//                                                         {m_input.quitAction, menuClickPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::RIGHT]}}};
//         XrInteractionProfileSuggestedBinding suggestedBindings{XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
//         suggestedBindings.interactionProfile = oculusTouchInteractionProfilePath;
//         suggestedBindings.suggestedBindings = bindings.data();
//         suggestedBindings.countSuggestedBindings = (uint32_t)bindings.size();
//         CHECK_XRCMD(xrSuggestInteractionProfileBindings(m_instance, &suggestedBindings));
//     }
//     // Suggest bindings for the Vive Controller.
//     {
//         XrPath viveControllerInteractionProfilePath;
//         CHECK_XRCMD(xrStringToPath(m_instance, "/interaction_profiles/htc/vive_controller", &viveControllerInteractionProfilePath));
//         std::vector<XrActionSuggestedBinding> bindings{{{m_input.grabAction, triggerValuePath[Side::LEFT]},
//                                                         {m_input.grabAction, triggerValuePath[Side::RIGHT]},
//                                                         {m_input.poseAction, posePath[Side::LEFT]},
//                                                         {m_input.poseAction, posePath[Side::RIGHT]},
//                                                         {m_input.quitAction, menuClickPath[Side::LEFT]},
//                                                         {m_input.quitAction, menuClickPath[Side::RIGHT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::RIGHT]}}};
//         XrInteractionProfileSuggestedBinding suggestedBindings{XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
//         suggestedBindings.interactionProfile = viveControllerInteractionProfilePath;
//         suggestedBindings.suggestedBindings = bindings.data();
//         suggestedBindings.countSuggestedBindings = (uint32_t)bindings.size();
//         CHECK_XRCMD(xrSuggestInteractionProfileBindings(m_instance, &suggestedBindings));
//     }
//
//     // Suggest bindings for the Valve Index Controller.
//     {
//         XrPath indexControllerInteractionProfilePath;
//         CHECK_XRCMD(
//             xrStringToPath(m_instance, "/interaction_profiles/valve/index_controller", &indexControllerInteractionProfilePath));
//         std::vector<XrActionSuggestedBinding> bindings{{{m_input.grabAction, squeezeForcePath[Side::LEFT]},
//                                                         {m_input.grabAction, squeezeForcePath[Side::RIGHT]},
//                                                         {m_input.poseAction, posePath[Side::LEFT]},
//                                                         {m_input.poseAction, posePath[Side::RIGHT]},
//                                                         {m_input.quitAction, bClickPath[Side::LEFT]},
//                                                         {m_input.quitAction, bClickPath[Side::RIGHT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::RIGHT]}}};
//         XrInteractionProfileSuggestedBinding suggestedBindings{XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
//         suggestedBindings.interactionProfile = indexControllerInteractionProfilePath;
//         suggestedBindings.suggestedBindings = bindings.data();
//         suggestedBindings.countSuggestedBindings = (uint32_t)bindings.size();
//         CHECK_XRCMD(xrSuggestInteractionProfileBindings(m_instance, &suggestedBindings));
//     }
//
//     // Suggest bindings for the Microsoft Mixed Reality Motion Controller.
//     {
//         XrPath microsoftMixedRealityInteractionProfilePath;
//         CHECK_XRCMD(xrStringToPath(m_instance, "/interaction_profiles/microsoft/motion_controller",
//                                    &microsoftMixedRealityInteractionProfilePath));
//         std::vector<XrActionSuggestedBinding> bindings{{{m_input.grabAction, squeezeClickPath[Side::LEFT]},
//                                                         {m_input.grabAction, squeezeClickPath[Side::RIGHT]},
//                                                         {m_input.poseAction, posePath[Side::LEFT]},
//                                                         {m_input.poseAction, posePath[Side::RIGHT]},
//                                                         {m_input.quitAction, menuClickPath[Side::LEFT]},
//                                                         {m_input.quitAction, menuClickPath[Side::RIGHT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::LEFT]},
//                                                         {m_input.vibrateAction, hapticPath[Side::RIGHT]}}};
//         XrInteractionProfileSuggestedBinding suggestedBindings{XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING};
//         suggestedBindings.interactionProfile = microsoftMixedRealityInteractionProfilePath;
//         suggestedBindings.suggestedBindings = bindings.data();
//         suggestedBindings.countSuggestedBindings = (uint32_t)bindings.size();
//         CHECK_XRCMD(xrSuggestInteractionProfileBindings(m_instance, &suggestedBindings));
//     }
//     XrActionSpaceCreateInfo actionSpaceInfo{XR_TYPE_ACTION_SPACE_CREATE_INFO};
//     actionSpaceInfo.action = m_input.poseAction;
//     actionSpaceInfo.poseInActionSpace.orientation.w = 1.f;
//     actionSpaceInfo.subactionPath = m_input.handSubactionPath[Side::LEFT];
//     CHECK_XRCMD(xrCreateActionSpace(m_session, &actionSpaceInfo, &m_input.handSpace[Side::LEFT]));
//     actionSpaceInfo.subactionPath = m_input.handSubactionPath[Side::RIGHT];
//     CHECK_XRCMD(xrCreateActionSpace(m_session, &actionSpaceInfo, &m_input.handSpace[Side::RIGHT]));
//
//     XrSessionActionSetsAttachInfo attachInfo{XR_TYPE_SESSION_ACTION_SETS_ATTACH_INFO};
//     attachInfo.countActionSets = 1;
//     attachInfo.actionSets = &m_input.actionSet;
//     CHECK_XRCMD(xrAttachSessionActionSets(m_session, &attachInfo));
// }

// static void LogActionSourceName(XrAction action, const std::string& actionName) {
//     XrBoundSourcesForActionEnumerateInfo getInfo = {XR_TYPE_BOUND_SOURCES_FOR_ACTION_ENUMERATE_INFO};
//     getInfo.action = action;
//     uint32_t pathCount = 0;
//     CHECK_XRCMD(xrEnumerateBoundSourcesForAction(m_session, &getInfo, 0, &pathCount, nullptr));
//     std::vector<XrPath> paths(pathCount);
//     CHECK_XRCMD(xrEnumerateBoundSourcesForAction(m_session, &getInfo, uint32_t(paths.size()), &pathCount, paths.data()));
//
//     std::string sourceName;
//     for (uint32_t i = 0; i < pathCount; ++i) {
//         constexpr XrInputSourceLocalizedNameFlags all = XR_INPUT_SOURCE_LOCALIZED_NAME_USER_PATH_BIT |
//                                                         XR_INPUT_SOURCE_LOCALIZED_NAME_INTERACTION_PROFILE_BIT |
//                                                         XR_INPUT_SOURCE_LOCALIZED_NAME_COMPONENT_BIT;
//
//         XrInputSourceLocalizedNameGetInfo nameInfo = {XR_TYPE_INPUT_SOURCE_LOCALIZED_NAME_GET_INFO};
//         nameInfo.sourcePath = paths[i];
//         nameInfo.whichComponents = all;
//
//         uint32_t size = 0;
//         CHECK_XRCMD(xrGetInputSourceLocalizedName(m_session, &nameInfo, 0, &size, nullptr));
//         if (size < 1) {
//             continue;
//         }
//         std::vector<char> grabSource(size);
//         CHECK_XRCMD(xrGetInputSourceLocalizedName(m_session, &nameInfo, uint32_t(grabSource.size()), &size, grabSource.data()));
//         if (!sourceName.empty()) {
//             sourceName += " and ";
//         }
//         sourceName += "'";
//         sourceName += std::string(grabSource.data(), size - 1);
//         sourceName += "'";
//     }
//
//     Log::Write(Log::Level::Info,
//                Fmt("%s action is bound to %s", actionName.c_str(), ((!sourceName.empty()) ? sourceName.c_str() : "nothing")));
// }

pub fn PollActions() void {
    // m_input.handActive = .{ c.XR_FALSE, c.XR_FALSE };

    // Sync actions
    // const activeActionSet: c.XrActiveActionSet = .{ .actionSet = m_input.actionSet, .subactionPath = c.XR_NULL_PATH };
    //     XrActionsSyncInfo syncInfo{XR_TYPE_ACTIONS_SYNC_INFO};
    //     syncInfo.countActiveActionSets = 1;
    //     syncInfo.activeActionSets = &activeActionSet;
    //     CHECK_XRCMD(xrSyncActions(m_session, &syncInfo));

    //     // Get pose and grab action state and start haptic vibrate when hand is 90% squeezed.
    //     for (auto hand : {Side::LEFT, Side::RIGHT}) {
    //         XrActionStateGetInfo getInfo{XR_TYPE_ACTION_STATE_GET_INFO};
    //         getInfo.action = m_input.grabAction;
    //         getInfo.subactionPath = m_input.handSubactionPath[hand];
    //
    //         XrActionStateFloat grabValue{XR_TYPE_ACTION_STATE_FLOAT};
    //         CHECK_XRCMD(xrGetActionStateFloat(m_session, &getInfo, &grabValue));
    //         if (grabValue.isActive == XR_TRUE) {
    //             // Scale the rendered hand by 1.0f (open) to 0.5f (fully squeezed).
    //             m_input.handScale[hand] = 1.0f - 0.5f * grabValue.currentState;
    //             if (grabValue.currentState > 0.9f) {
    //                 XrHapticVibration vibration{XR_TYPE_HAPTIC_VIBRATION};
    //                 vibration.amplitude = 0.5;
    //                 vibration.duration = XR_MIN_HAPTIC_DURATION;
    //                 vibration.frequency = XR_FREQUENCY_UNSPECIFIED;
    //
    //                 XrHapticActionInfo hapticActionInfo{XR_TYPE_HAPTIC_ACTION_INFO};
    //                 hapticActionInfo.action = m_input.vibrateAction;
    //                 hapticActionInfo.subactionPath = m_input.handSubactionPath[hand];
    //                 CHECK_XRCMD(xrApplyHapticFeedback(m_session, &hapticActionInfo, (XrHapticBaseHeader*)&vibration));
    //             }
    //         }
    //
    //         getInfo.action = m_input.poseAction;
    //         XrActionStatePose poseState{XR_TYPE_ACTION_STATE_POSE};
    //         CHECK_XRCMD(xrGetActionStatePose(m_session, &getInfo, &poseState));
    //         m_input.handActive[hand] = poseState.isActive;
    //     }
    //
    //     // There were no subaction paths specified for the quit action, because we don't care which hand did it.
    //     XrActionStateGetInfo getInfo{XR_TYPE_ACTION_STATE_GET_INFO, nullptr, m_input.quitAction, XR_NULL_PATH};
    //     XrActionStateBoolean quitValue{XR_TYPE_ACTION_STATE_BOOLEAN};
    //     CHECK_XRCMD(xrGetActionStateBoolean(m_session, &getInfo, &quitValue));
    //     if ((quitValue.isActive == XR_TRUE) && (quitValue.changedSinceLastSync == XR_TRUE) && (quitValue.currentState == XR_TRUE)) {
    //         CHECK_XRCMD(xrRequestExitSession(m_session));
    //     }
}


