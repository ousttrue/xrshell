const std = @import("std");
const c = @import("c");
const xr_util = @import("xr_util");
const XrError = xr_util.XrError;
const XrResult = xr_util.XrResult;

pub const Side = struct {
    pub const LEFT = 0;
    pub const RIGHT = 1;
    pub const COUNT = 2;
};
const hands = [2]usize{ Side.LEFT, Side.RIGHT };

pub const InputState = struct {
    actionSet: c.XrActionSet = null,
    grabAction: c.XrAction = null,
    poseAction: c.XrAction = null,
    vibrateAction: c.XrAction = null,
    quitAction: c.XrAction = null,
    handSubactionPath: [Side.COUNT]c.XrPath = undefined,
    handSpace: [Side.COUNT]c.XrSpace = undefined,
    handScale: [Side.COUNT]f32 = .{ 1.0, 1.0 },
    handActive: [Side.COUNT]c.XrBool32 = undefined,
};

pub var m_input: InputState = .{};

pub fn init() void {}

pub fn deinit() void {
    if (m_input.actionSet != null) {
        for (hands) |hand| {
            _ = c.xrDestroySpace(m_input.handSpace[hand]);
        }
        _ = c.xrDestroyActionSet(m_input.actionSet);
    }
}

pub fn InitializeActions(instance: c.XrInstance, session: c.XrSession) XrError!void {
    // Create an action set.
    {
        var actionSetInfo: c.XrActionSetCreateInfo = .{
            .type = c.XR_TYPE_ACTION_SET_CREATE_INFO,
            .priority = 0,
        };
        _ = std.fmt.bufPrintZ(&actionSetInfo.actionSetName, "gameplay", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionSetInfo.localizedActionSetName, "Gameplay", .{}) catch @panic("OOM");
        _ = try XrResult.init(c.xrCreateActionSet(instance, &actionSetInfo, &m_input.actionSet));
    }

    // Get the XrPath for the left and right hands - we will use them as subaction paths.
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left", &m_input.handSubactionPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right", &m_input.handSubactionPath[Side.RIGHT]));

    // Create actions.
    {
        // Create an input action for grabbing objects with the left and right hands.
        var actionInfo: c.XrActionCreateInfo = .{
            .type = c.XR_TYPE_ACTION_CREATE_INFO,
            .actionType = c.XR_ACTION_TYPE_FLOAT_INPUT,
            .countSubactionPaths = m_input.handSubactionPath.len,
            .subactionPaths = &m_input.handSubactionPath,
        };
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "grab_object", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Grab Object", .{}) catch @panic("OOM");
        _ = try XrResult.init(c.xrCreateAction(m_input.actionSet, &actionInfo, &m_input.grabAction));

        // Create an input action getting the left and right hand poses.
        actionInfo.actionType = c.XR_ACTION_TYPE_POSE_INPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "hand_pose", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Hand Pose", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = m_input.handSubactionPath.len;
        actionInfo.subactionPaths = &m_input.handSubactionPath;
        _ = try XrResult.init(c.xrCreateAction(m_input.actionSet, &actionInfo, &m_input.poseAction));

        // Create output actions for vibrating the left and right controller.
        actionInfo.actionType = c.XR_ACTION_TYPE_VIBRATION_OUTPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "vibrate_hand", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Vibrate Hand", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = m_input.handSubactionPath.len;
        actionInfo.subactionPaths = &m_input.handSubactionPath;
        _ = try XrResult.init(c.xrCreateAction(m_input.actionSet, &actionInfo, &m_input.vibrateAction));

        // Create input actions for quitting the session using the left and right controller.
        // Since it doesn't matter which hand did this, we do not specify subaction paths for it.
        // We will just suggest bindings for both hands, where possible.
        actionInfo.actionType = c.XR_ACTION_TYPE_BOOLEAN_INPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "quit_session", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Quit Session", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = 0;
        actionInfo.subactionPaths = null;
        _ = try XrResult.init(c.xrCreateAction(m_input.actionSet, &actionInfo, &m_input.quitAction));
    }

    var selectPath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/select/click", &selectPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/select/click", &selectPath[Side.RIGHT]));
    var squeezeValuePath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/squeeze/value", &squeezeValuePath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/squeeze/value", &squeezeValuePath[Side.RIGHT]));
    var squeezeForcePath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/squeeze/force", &squeezeForcePath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/squeeze/force", &squeezeForcePath[Side.RIGHT]));
    var squeezeClickPath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/squeeze/click", &squeezeClickPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/squeeze/click", &squeezeClickPath[Side.RIGHT]));
    var posePath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/grip/pose", &posePath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/grip/pose", &posePath[Side.RIGHT]));
    var hapticPath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/output/haptic", &hapticPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/output/haptic", &hapticPath[Side.RIGHT]));
    var menuClickPath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/menu/click", &menuClickPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/menu/click", &menuClickPath[Side.RIGHT]));
    var bClickPath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/b/click", &bClickPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/b/click", &bClickPath[Side.RIGHT]));
    var triggerValuePath: [Side.COUNT]c.XrPath = undefined;
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left/input/trigger/value", &triggerValuePath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right/input/trigger/value", &triggerValuePath[Side.RIGHT]));

    // Suggest bindings for KHR Simple.
    {
        var khrSimpleInteractionProfilePath: c.XrPath = undefined;
        _ = try XrResult.init(c.xrStringToPath(instance, "/interaction_profiles/khr/simple_controller", &khrSimpleInteractionProfilePath));
        // Fall back to a click input for the grab action.
        const bindings = [_]c.XrActionSuggestedBinding{
            .{ .action = m_input.grabAction, .binding = selectPath[Side.LEFT] },
            .{ .action = m_input.grabAction, .binding = selectPath[Side.RIGHT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
        };
        var suggestedBindings: c.XrInteractionProfileSuggestedBinding = .{
            .type = c.XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING,
            .interactionProfile = khrSimpleInteractionProfilePath,
            .suggestedBindings = &bindings,
            .countSuggestedBindings = bindings.len,
        };
        _ = try XrResult.init(c.xrSuggestInteractionProfileBindings(instance, &suggestedBindings));
    }
    // Suggest bindings for the Oculus Touch.
    {
        var oculusTouchInteractionProfilePath: c.XrPath = undefined;
        _ = try XrResult.init(c.xrStringToPath(instance, "/interaction_profiles/oculus/touch_controller", &oculusTouchInteractionProfilePath));
        const bindings = [_]c.XrActionSuggestedBinding{
            .{ .action = m_input.grabAction, .binding = squeezeValuePath[Side.LEFT] },
            .{ .action = m_input.grabAction, .binding = squeezeValuePath[Side.RIGHT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
        };
        var suggestedBindings: c.XrInteractionProfileSuggestedBinding = .{
            .type = c.XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING,
            .interactionProfile = oculusTouchInteractionProfilePath,
            .suggestedBindings = &bindings,
            .countSuggestedBindings = bindings.len,
        };
        _ = try XrResult.init(c.xrSuggestInteractionProfileBindings(instance, &suggestedBindings));
    }
    // Suggest bindings for the Vive Controller.
    {
        var viveControllerInteractionProfilePath: c.XrPath = undefined;
        _ = try XrResult.init(c.xrStringToPath(instance, "/interaction_profiles/htc/vive_controller", &viveControllerInteractionProfilePath));
        const bindings = [_]c.XrActionSuggestedBinding{
            .{ .action = m_input.grabAction, .binding = triggerValuePath[Side.LEFT] },
            .{ .action = m_input.grabAction, .binding = triggerValuePath[Side.RIGHT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
        };
        var suggestedBindings: c.XrInteractionProfileSuggestedBinding = .{
            .type = c.XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING,
            .interactionProfile = viveControllerInteractionProfilePath,
            .suggestedBindings = &bindings,
            .countSuggestedBindings = bindings.len,
        };
        _ = try XrResult.init(c.xrSuggestInteractionProfileBindings(instance, &suggestedBindings));
    }
    // Suggest bindings for the Valve Index Controller.
    {
        var indexControllerInteractionProfilePath: c.XrPath = undefined;
        _ = try XrResult.init(c.xrStringToPath(instance, "/interaction_profiles/valve/index_controller", &indexControllerInteractionProfilePath));
        const bindings = [_]c.XrActionSuggestedBinding{
            .{ .action = m_input.grabAction, .binding = squeezeForcePath[Side.LEFT] },
            .{ .action = m_input.grabAction, .binding = squeezeForcePath[Side.RIGHT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = m_input.quitAction, .binding = bClickPath[Side.LEFT] },
            .{ .action = m_input.quitAction, .binding = bClickPath[Side.RIGHT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
        };
        var suggestedBindings: c.XrInteractionProfileSuggestedBinding = .{
            .type = c.XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING,
            .interactionProfile = indexControllerInteractionProfilePath,
            .suggestedBindings = &bindings,
            .countSuggestedBindings = bindings.len,
        };
        _ = try XrResult.init(c.xrSuggestInteractionProfileBindings(instance, &suggestedBindings));
    }
    // Suggest bindings for the Microsoft Mixed Reality Motion Controller.
    {
        var microsoftMixedRealityInteractionProfilePath: c.XrPath = undefined;
        _ = try XrResult.init(c.xrStringToPath(instance, "/interaction_profiles/microsoft/motion_controller", &microsoftMixedRealityInteractionProfilePath));
        const bindings = [_]c.XrActionSuggestedBinding{
            .{ .action = m_input.grabAction, .binding = squeezeClickPath[Side.LEFT] },
            .{ .action = m_input.grabAction, .binding = squeezeClickPath[Side.RIGHT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = m_input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = m_input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = m_input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
        };
        var suggestedBindings: c.XrInteractionProfileSuggestedBinding = .{
            .type = c.XR_TYPE_INTERACTION_PROFILE_SUGGESTED_BINDING,
            .interactionProfile = microsoftMixedRealityInteractionProfilePath,
            .suggestedBindings = &bindings,
            .countSuggestedBindings = bindings.len,
        };
        _ = try XrResult.init(c.xrSuggestInteractionProfileBindings(instance, &suggestedBindings));
    }

    var actionSpaceInfo: c.XrActionSpaceCreateInfo = .{
        .type = c.XR_TYPE_ACTION_SPACE_CREATE_INFO,
        .action = m_input.poseAction,
        .poseInActionSpace = .{ .orientation = .{ .w = 1.0 } },
        .subactionPath = m_input.handSubactionPath[Side.LEFT],
    };
    _ = try XrResult.init(c.xrCreateActionSpace(session, &actionSpaceInfo, &m_input.handSpace[Side.LEFT]));
    actionSpaceInfo.subactionPath = m_input.handSubactionPath[Side.RIGHT];
    _ = try XrResult.init(c.xrCreateActionSpace(session, &actionSpaceInfo, &m_input.handSpace[Side.RIGHT]));

    var attachInfo: c.XrSessionActionSetsAttachInfo = .{
        .type = c.XR_TYPE_SESSION_ACTION_SETS_ATTACH_INFO,
        .countActionSets = 1,
        .actionSets = &m_input.actionSet,
    };
    _ = try XrResult.init(c.xrAttachSessionActionSets(session, &attachInfo));
}

pub fn LogEvent(allocator: std.mem.Allocator, session: c.XrSession) !void {
    try LogActionSourceName(allocator, session, m_input.grabAction, "Grab");
    try LogActionSourceName(allocator, session, m_input.quitAction, "Quit");
    try LogActionSourceName(allocator, session, m_input.poseAction, "Pose");
    try LogActionSourceName(allocator, session, m_input.vibrateAction, "Vibrate");
}

fn LogActionSourceName(
    allocator: std.mem.Allocator,
    session: c.XrSession,
    action: c.XrAction,
    actionName: []const u8,
) !void {
    var getInfo: c.XrBoundSourcesForActionEnumerateInfo = .{
        .type = c.XR_TYPE_BOUND_SOURCES_FOR_ACTION_ENUMERATE_INFO,
        .action = action,
    };
    var pathCount: u32 = 0;
    _ = try XrResult.init(c.xrEnumerateBoundSourcesForAction(session, &getInfo, 0, &pathCount, null));

    const paths = try allocator.alloc(c.XrPath, pathCount);
    defer allocator.free(paths);
    _ = try XrResult.init(c.xrEnumerateBoundSourcesForAction(session, &getInfo, @intCast(paths.len), &pathCount, paths.ptr));

    var sourceName: std.ArrayList(u8) = .{};
    defer sourceName.deinit(allocator);
    for (0..pathCount) |i| {
        const all: c.XrInputSourceLocalizedNameFlags = c.XR_INPUT_SOURCE_LOCALIZED_NAME_USER_PATH_BIT |
            c.XR_INPUT_SOURCE_LOCALIZED_NAME_INTERACTION_PROFILE_BIT |
            c.XR_INPUT_SOURCE_LOCALIZED_NAME_COMPONENT_BIT;

        var nameInfo: c.XrInputSourceLocalizedNameGetInfo = .{
            .type = c.XR_TYPE_INPUT_SOURCE_LOCALIZED_NAME_GET_INFO,
            .sourcePath = paths[i],
            .whichComponents = all,
        };
        var size: u32 = 0;
        _ = try XrResult.init(c.xrGetInputSourceLocalizedName(session, &nameInfo, 0, &size, null));
        if (size < 1) {
            continue;
        }
        var grabSource = try allocator.alloc(u8, size);
        defer allocator.free(grabSource);
        _ = try XrResult.init(c.xrGetInputSourceLocalizedName(session, &nameInfo, @intCast(grabSource.len), &size, grabSource.ptr));
        if (sourceName.items.len > 0) {
            try sourceName.appendSlice(allocator, " and ");
        }
        try sourceName.appendSlice(allocator, "'");
        try sourceName.appendSlice(allocator, grabSource[0 .. size - 1]);
        try sourceName.appendSlice(allocator, "'");
    }

    std.log.info("{s} action is bound to {s}", .{
        actionName,
        if (sourceName.items.len > 0) sourceName.items else "nothing",
    });
}

pub fn PollActions(session: c.XrSession) XrError!void {
    m_input.handActive = .{ c.XR_FALSE, c.XR_FALSE };

    // Sync actions
    const activeActionSet: c.XrActiveActionSet = .{ .actionSet = m_input.actionSet, .subactionPath = c.XR_NULL_PATH };
    var syncInfo: c.XrActionsSyncInfo = .{
        .type = c.XR_TYPE_ACTIONS_SYNC_INFO,
        .countActiveActionSets = 1,
        .activeActionSets = &activeActionSet,
    };
    _ = try XrResult.init(c.xrSyncActions(session, &syncInfo));

    // Get pose and grab action state and start haptic vibrate when hand is 90% squeezed.
    for (hands) |hand| {
        var getInfo: c.XrActionStateGetInfo = .{
            .type = c.XR_TYPE_ACTION_STATE_GET_INFO,
            .action = m_input.grabAction,
            .subactionPath = m_input.handSubactionPath[hand],
        };
        var grabValue: c.XrActionStateFloat = .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT };
        _ = try XrResult.init(c.xrGetActionStateFloat(session, &getInfo, &grabValue));
        if (grabValue.isActive == c.XR_TRUE) {
            // Scale the rendered hand by 1.0f (open) to 0.5f (fully squeezed).
            m_input.handScale[hand] = 1.0 - 0.5 * grabValue.currentState;
            if (grabValue.currentState > 0.9) {
                var vibration: c.XrHapticVibration = .{
                    .type = c.XR_TYPE_HAPTIC_VIBRATION,
                    .amplitude = 0.5,
                    .duration = c.XR_MIN_HAPTIC_DURATION,
                    .frequency = c.XR_FREQUENCY_UNSPECIFIED,
                };
                var hapticActionInfo: c.XrHapticActionInfo = .{
                    .type = c.XR_TYPE_HAPTIC_ACTION_INFO,
                    .action = m_input.vibrateAction,
                    .subactionPath = m_input.handSubactionPath[hand],
                };
                _ = try XrResult.init(c.xrApplyHapticFeedback(session, &hapticActionInfo, @ptrCast(&vibration)));
            }
        }

        getInfo.action = m_input.poseAction;
        var poseState: c.XrActionStatePose = .{ .type = c.XR_TYPE_ACTION_STATE_POSE };
        _ = try XrResult.init(c.xrGetActionStatePose(session, &getInfo, &poseState));
        m_input.handActive[hand] = poseState.isActive;
    }

    // There were no subaction paths specified for the quit action, because we don't care which hand did it.
    var getInfo: c.XrActionStateGetInfo = .{
        .type = c.XR_TYPE_ACTION_STATE_GET_INFO,
        .next = null,
        .action = m_input.quitAction,
        .subactionPath = c.XR_NULL_PATH,
    };
    var quitValue: c.XrActionStateBoolean = .{ .type = c.XR_TYPE_ACTION_STATE_BOOLEAN };
    _ = try XrResult.init(c.xrGetActionStateBoolean(session, &getInfo, &quitValue));
    if ((quitValue.isActive == c.XR_TRUE) and (quitValue.changedSinceLastSync == c.XR_TRUE) and (quitValue.currentState == c.XR_TRUE)) {
        _ = try XrResult.init(c.xrRequestExitSession(session));
    }
}
