// Copyright (c) 2017-2025 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

#include "common.h"
#include "options.h"
#include "openxr_program.h"
#include <thread>

#if defined(_WIN32)
// Favor the high performance NVIDIA or AMD GPUs
extern "C" {
// http://developer.download.nvidia.com/devzone/devcenter/gamegraphics/files/OptimusRenderingPolicies.pdf
__declspec(dllexport) DWORD NvOptimusEnablement = 0x00000001;
// https://gpuopen.com/learn/amdpowerxpressrequesthighperformance/
__declspec(dllexport) DWORD AmdPowerXpressRequestHighPerformance = 0x00000001;
}
#endif  // defined(_WIN32)

int main(int argc, char* argv[]) {
    Options options = {};
    try {
        // Parse command-line arguments into Options.
        // memset(options.get(), 0, sizeof(Options));
        if (!UpdateOptionsFromCommandLine(&options, argc, argv)) {
            return 1;
        }

        // std::shared_ptr<PlatformData> data = std::make_shared<PlatformData>();

        // Spawn a thread to wait for a keypress
        static bool quitKeyPressed = false;
        auto exitPollingThread = std::thread{[] {
            Log::Write(Log::Level::Info, "Press any key to shutdown...");
            (void)getchar();
            quitKeyPressed = true;
        }};
        exitPollingThread.detach();

        bool requestRestart = false;
        do {
            // Initialize the OpenXR program.
            XR_PROG_OpenXrProgram_init(&options);

            XR_PROG_CreateInstance();
            XR_PROG_InitializeSystem();

            SetEnvironmentBlendMode(&options, XR_PROG_GetPreferredBlendMode());
            UpdateOptionsFromCommandLine(&options, argc, argv);

            XR_PROG_InitializeDevice();
            XR_PROG_InitializeSession();
            XR_PROG_CreateSwapchains();

            while (!quitKeyPressed) {
                bool exitRenderLoop = false;
                XR_PROG_PollEvents(&exitRenderLoop, &requestRestart);
                if (exitRenderLoop) {
                    break;
                }

                if (XR_PROG_IsSessionRunning()) {
                    XR_PROG_PollActions();
                    XR_PROG_RenderFrame();
                } else {
                    // Throttle loop since xrWaitFrame won't be called.
                    std::this_thread::sleep_for(std::chrono::milliseconds(250));
                }
            }

        } while (!quitKeyPressed && requestRestart);

        return 0;
    } catch (const std::exception& ex) {
        Log::Write(Log::Level::Error, ex.what());
        return 1;
    } catch (...) {
        Log::Write(Log::Level::Error, "Unknown Error");
        return 1;
    }
}
