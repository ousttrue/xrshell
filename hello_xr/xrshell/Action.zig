const std = @import("std");
const c = @import("c");
const xr_result = @import("xr_result.zig");
const XrError = xr_result.XrError;
const XrResult = xr_result.XrResult;
const Cube = @import("../Cube.zig");
const geometry = @import("../geometry.zig");

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

allocator: std.mem.Allocator,
instance: c.XrInstance,
session: c.XrSession,
visualizedSpaces: std.ArrayList(c.XrSpace) = .{},
input: InputState = .{},
cubes: std.ArrayList(Cube) = .{},

pub fn init(
    allocator: std.mem.Allocator,
    instance: c.XrInstance,
    session: c.XrSession,
) !@This() {
    std.log.info("## Action.init ##", .{});
    var this = @This(){
        .allocator = allocator,
        .instance = instance,
        .session = session,
    };

    const visualizedSpaces = [_][]const u8{
        "ViewFront", "Local", "Stage", "StageLeft", "StageRight", "StageLeftRotated", "StageRightRotated",
    };

    for (visualizedSpaces) |visualizedSpace| {
        const referenceSpaceCreateInfo = geometry.GetXrReferenceSpaceCreateInfo(visualizedSpace);
        var space: c.XrSpace = undefined;
        const res = c.xrCreateReferenceSpace(this.session, &referenceSpaceCreateInfo, &space);
        if (c.XR_SUCCEEDED(res)) {
            try this.visualizedSpaces.append(this.allocator, space);
        } else {
            std.log.warn("Failed to create reference space {s} with error {}", .{ visualizedSpace, res });
        }
    }

    // Create an action set.
    {
        var actionSetInfo: c.XrActionSetCreateInfo = .{
            .type = c.XR_TYPE_ACTION_SET_CREATE_INFO,
            .priority = 0,
        };
        _ = std.fmt.bufPrintZ(&actionSetInfo.actionSetName, "gameplay", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionSetInfo.localizedActionSetName, "Gameplay", .{}) catch @panic("OOM");
        _ = try XrResult.init(c.xrCreateActionSet(instance, &actionSetInfo, &this.input.actionSet));
    }

    // Get the XrPath for the left and right hands - we will use them as subaction paths.
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/left", &this.input.handSubactionPath[Side.LEFT]));
    _ = try XrResult.init(c.xrStringToPath(instance, "/user/hand/right", &this.input.handSubactionPath[Side.RIGHT]));

    // Create actions.
    {
        // Create an input action for grabbing objects with the left and right hands.
        var actionInfo: c.XrActionCreateInfo = .{
            .type = c.XR_TYPE_ACTION_CREATE_INFO,
            .actionType = c.XR_ACTION_TYPE_FLOAT_INPUT,
            .countSubactionPaths = this.input.handSubactionPath.len,
            .subactionPaths = &this.input.handSubactionPath,
        };
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "grab_object", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Grab Object", .{}) catch @panic("OOM");
        _ = try XrResult.init(c.xrCreateAction(this.input.actionSet, &actionInfo, &this.input.grabAction));

        // Create an input action getting the left and right hand poses.
        actionInfo.actionType = c.XR_ACTION_TYPE_POSE_INPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "hand_pose", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Hand Pose", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = this.input.handSubactionPath.len;
        actionInfo.subactionPaths = &this.input.handSubactionPath;
        _ = try XrResult.init(c.xrCreateAction(this.input.actionSet, &actionInfo, &this.input.poseAction));

        // Create output actions for vibrating the left and right controller.
        actionInfo.actionType = c.XR_ACTION_TYPE_VIBRATION_OUTPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "vibrate_hand", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Vibrate Hand", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = this.input.handSubactionPath.len;
        actionInfo.subactionPaths = &this.input.handSubactionPath;
        _ = try XrResult.init(c.xrCreateAction(this.input.actionSet, &actionInfo, &this.input.vibrateAction));

        // Create input actions for quitting the session using the left and right controller.
        // Since it doesn't matter which hand did this, we do not specify subaction paths for it.
        // We will just suggest bindings for both hands, where possible.
        actionInfo.actionType = c.XR_ACTION_TYPE_BOOLEAN_INPUT;
        _ = std.fmt.bufPrintZ(&actionInfo.actionName, "quit_session", .{}) catch @panic("OOM");
        _ = std.fmt.bufPrintZ(&actionInfo.localizedActionName, "Quit Session", .{}) catch @panic("OOM");
        actionInfo.countSubactionPaths = 0;
        actionInfo.subactionPaths = null;
        _ = try XrResult.init(c.xrCreateAction(this.input.actionSet, &actionInfo, &this.input.quitAction));
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
            .{ .action = this.input.grabAction, .binding = selectPath[Side.LEFT] },
            .{ .action = this.input.grabAction, .binding = selectPath[Side.RIGHT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
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
            .{ .action = this.input.grabAction, .binding = squeezeValuePath[Side.LEFT] },
            .{ .action = this.input.grabAction, .binding = squeezeValuePath[Side.RIGHT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
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
            .{ .action = this.input.grabAction, .binding = triggerValuePath[Side.LEFT] },
            .{ .action = this.input.grabAction, .binding = triggerValuePath[Side.RIGHT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
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
            .{ .action = this.input.grabAction, .binding = squeezeForcePath[Side.LEFT] },
            .{ .action = this.input.grabAction, .binding = squeezeForcePath[Side.RIGHT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = this.input.quitAction, .binding = bClickPath[Side.LEFT] },
            .{ .action = this.input.quitAction, .binding = bClickPath[Side.RIGHT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
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
            .{ .action = this.input.grabAction, .binding = squeezeClickPath[Side.LEFT] },
            .{ .action = this.input.grabAction, .binding = squeezeClickPath[Side.RIGHT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.LEFT] },
            .{ .action = this.input.poseAction, .binding = posePath[Side.RIGHT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.LEFT] },
            .{ .action = this.input.quitAction, .binding = menuClickPath[Side.RIGHT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.LEFT] },
            .{ .action = this.input.vibrateAction, .binding = hapticPath[Side.RIGHT] },
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
        .action = this.input.poseAction,
        .poseInActionSpace = .{ .orientation = .{ .w = 1.0 } },
        .subactionPath = this.input.handSubactionPath[Side.LEFT],
    };
    _ = try XrResult.init(c.xrCreateActionSpace(session, &actionSpaceInfo, &this.input.handSpace[Side.LEFT]));
    actionSpaceInfo.subactionPath = this.input.handSubactionPath[Side.RIGHT];
    _ = try XrResult.init(c.xrCreateActionSpace(session, &actionSpaceInfo, &this.input.handSpace[Side.RIGHT]));

    var attachInfo: c.XrSessionActionSetsAttachInfo = .{
        .type = c.XR_TYPE_SESSION_ACTION_SETS_ATTACH_INFO,
        .countActionSets = 1,
        .actionSets = &this.input.actionSet,
    };
    _ = try XrResult.init(c.xrAttachSessionActionSets(session, &attachInfo));

    return this;
}

pub fn deinit(this: *@This()) void {
    std.log.info("## Action.deinit ##", .{});
    this.cubes.deinit(this.allocator);
    if (this.input.actionSet != null) {
        for (hands) |hand| {
            _ = c.xrDestroySpace(this.input.handSpace[hand]);
        }
        _ = c.xrDestroyActionSet(this.input.actionSet);
    }

    for (this.visualizedSpaces.items) |space| {
        _ = c.xrDestroySpace(space);
    }
    this.visualizedSpaces.deinit(this.allocator);
}

pub fn logEvent(this: *@This()) !void {
    try logActionSourceName(this.allocator, this.session, this.input.grabAction, "Grab");
    try logActionSourceName(this.allocator, this.session, this.input.quitAction, "Quit");
    try logActionSourceName(this.allocator, this.session, this.input.poseAction, "Pose");
    try logActionSourceName(this.allocator, this.session, this.input.vibrateAction, "Vibrate");
}

fn logActionSourceName(
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

pub fn pollActions(this: *@This()) XrError!void {
    this.input.handActive = .{ c.XR_FALSE, c.XR_FALSE };

    // Sync actions
    const activeActionSet: c.XrActiveActionSet = .{ .actionSet = this.input.actionSet, .subactionPath = c.XR_NULL_PATH };
    var syncInfo: c.XrActionsSyncInfo = .{
        .type = c.XR_TYPE_ACTIONS_SYNC_INFO,
        .countActiveActionSets = 1,
        .activeActionSets = &activeActionSet,
    };
    _ = try XrResult.init(c.xrSyncActions(this.session, &syncInfo));

    // Get pose and grab action state and start haptic vibrate when hand is 90% squeezed.
    for (hands) |hand| {
        var getInfo: c.XrActionStateGetInfo = .{
            .type = c.XR_TYPE_ACTION_STATE_GET_INFO,
            .action = this.input.grabAction,
            .subactionPath = this.input.handSubactionPath[hand],
        };
        var grabValue: c.XrActionStateFloat = .{ .type = c.XR_TYPE_ACTION_STATE_FLOAT };
        _ = try XrResult.init(c.xrGetActionStateFloat(this.session, &getInfo, &grabValue));
        if (grabValue.isActive == c.XR_TRUE) {
            // Scale the rendered hand by 1.0f (open) to 0.5f (fully squeezed).
            this.input.handScale[hand] = 1.0 - 0.5 * grabValue.currentState;
            if (grabValue.currentState > 0.9) {
                var vibration: c.XrHapticVibration = .{
                    .type = c.XR_TYPE_HAPTIC_VIBRATION,
                    .amplitude = 0.5,
                    .duration = c.XR_MIN_HAPTIC_DURATION,
                    .frequency = c.XR_FREQUENCY_UNSPECIFIED,
                };
                var hapticActionInfo: c.XrHapticActionInfo = .{
                    .type = c.XR_TYPE_HAPTIC_ACTION_INFO,
                    .action = this.input.vibrateAction,
                    .subactionPath = this.input.handSubactionPath[hand],
                };
                _ = try XrResult.init(c.xrApplyHapticFeedback(this.session, &hapticActionInfo, @ptrCast(&vibration)));
            }
        }

        getInfo.action = this.input.poseAction;
        var poseState: c.XrActionStatePose = .{ .type = c.XR_TYPE_ACTION_STATE_POSE };
        _ = try XrResult.init(c.xrGetActionStatePose(this.session, &getInfo, &poseState));
        this.input.handActive[hand] = poseState.isActive;
    }

    // There were no subaction paths specified for the quit action, because we don't care which hand did it.
    var getInfo: c.XrActionStateGetInfo = .{
        .type = c.XR_TYPE_ACTION_STATE_GET_INFO,
        .next = null,
        .action = this.input.quitAction,
        .subactionPath = c.XR_NULL_PATH,
    };
    var quitValue: c.XrActionStateBoolean = .{ .type = c.XR_TYPE_ACTION_STATE_BOOLEAN };
    _ = try XrResult.init(c.xrGetActionStateBoolean(this.session, &getInfo, &quitValue));
    if ((quitValue.isActive == c.XR_TRUE) and (quitValue.changedSinceLastSync == c.XR_TRUE) and (quitValue.currentState == c.XR_TRUE)) {
        _ = try XrResult.init(c.xrRequestExitSession(this.session));
    }
}

pub fn update(
    this: *@This(),
    space: c.XrSpace,
    predictedDisplayTime: c.XrTime,
) ![]const Cube {
    try this.cubes.resize(this.allocator, 0);
    // For each locatable space that we want to visualize, render a 25cm cube.
    for (this.visualizedSpaces.items) |visualizedSpace| {
        var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
        const res = try XrResult.init(c.xrLocateSpace(visualizedSpace, space, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                try this.cubes.append(this.allocator, .init(spaceLocation.pose, .{ .x = 0.25, .y = 0.25, .z = 0.25 }));
            }
        } else {
            std.log.debug("Unable to locate a visualized reference space in app space: {}", .{res});
        }
    }

    // Render a 10cm cube scaled by grabAction for each hand. Note renderHand will only be
    // true when the application has focus.
    for (hands) |hand| {
        var spaceLocation: c.XrSpaceLocation = .{ .type = c.XR_TYPE_SPACE_LOCATION };
        const res = try XrResult.init(c.xrLocateSpace(this.input.handSpace[hand], space, predictedDisplayTime, &spaceLocation));
        if (res == .Success) {
            if ((spaceLocation.locationFlags & c.XR_SPACE_LOCATION_POSITION_VALID_BIT) != 0 and
                (spaceLocation.locationFlags & c.XR_SPACE_LOCATION_ORIENTATION_VALID_BIT) != 0)
            {
                const scale = 0.1 * this.input.handScale[hand];
                try this.cubes.append(this.allocator, .init(spaceLocation.pose, .{ .x = scale, .y = scale, .z = scale }));
            }
        } else {
            // Tracking loss is expected when the hand is not active so only log a message
            // if the hand is active.
            if (this.input.handActive[hand] == c.XR_TRUE) {
                const handName = [2][]const u8{ "left", "right" };
                std.log.debug("Unable to locate {s} hand action space in app space: {}", .{ handName[hand], res });
            }
        }
    }

    return this.cubes.items;
}
