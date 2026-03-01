// Copyright (c) 2017-2025 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <openxr/openxr.h>
#include <array>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

struct FixedString {
    char c_str[32] = {0};
    FixedString() { c_str[0] = 0; }
    FixedString(const char* src) { memcpy(c_str, src, strlen(src)); }
};

struct Options {
    FixedString GraphicsPlugin = {};
    FixedString FormFactor = FixedString("Hmd");
    FixedString ViewConfiguration = FixedString("Stereo");
    FixedString EnvironmentBlendMode = FixedString("Opaque");
    FixedString AppSpace = FixedString("Local");
    struct {
        XrFormFactor FormFactor{XR_FORM_FACTOR_HEAD_MOUNTED_DISPLAY};
        XrViewConfigurationType ViewConfigType{XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO};
        XrEnvironmentBlendMode EnvironmentBlendMode{XR_ENVIRONMENT_BLEND_MODE_OPAQUE};
    } Parsed;

    std::array<float, 4> GetBackgroundClearColor() const {
        static const std::array<float, 4> SlateGrey{0.184313729f, 0.309803933f, 0.309803933f, 1.0f};
        static const std::array<float, 4> TransparentBlack{0.0f, 0.0f, 0.0f, 0.0f};
        static const std::array<float, 4> Black{0.0f, 0.0f, 0.0f, 1.0f};
        switch (Parsed.EnvironmentBlendMode) {
            case XR_ENVIRONMENT_BLEND_MODE_OPAQUE:
                return SlateGrey;
            case XR_ENVIRONMENT_BLEND_MODE_ADDITIVE:
                return Black;
            case XR_ENVIRONMENT_BLEND_MODE_ALPHA_BLEND:
                return TransparentBlack;
            default:
                return SlateGrey;
        }
    }
};
bool UpdateOptionsFromCommandLine(Options* options, int argc, char* argv[]);
void SetEnvironmentBlendMode(Options* options, XrEnvironmentBlendMode environmentBlendMode);

#ifdef __cplusplus
}
#endif
