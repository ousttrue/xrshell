// Copyright (c) 2017-2025 The Khronos Group Inc.
//
// SPDX-License-Identifier: Apache-2.0

#include "common.h"
#include "options.h"

#include "platformdata.h"
#include "platformplugin.h"
#include "graphicsplugin.h"
#include "openxr_program.h"

#include <thread>
#include <string.h>

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
    try {
        // Parse command-line arguments into Options.
        auto options = std::make_shared<Options>();
        // memset(options.get(), 0, sizeof(Options));
        if (!UpdateOptionsFromCommandLine(options.get(), argc, argv)) {
            return 1;
        }

        std::shared_ptr<PlatformData> data = std::make_shared<PlatformData>();

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
            // Create platform-specific implementation.
            std::shared_ptr<IPlatformPlugin> platformPlugin = CreatePlatformPlugin(options, data);

            // Create graphics API implementation.
            std::shared_ptr<IGraphicsPlugin> graphicsPlugin = CreateGraphicsPlugin(options, platformPlugin);

            // Initialize the OpenXR program.
            OpenXrProgram program(options, platformPlugin, graphicsPlugin);

            program.CreateInstance();
            program.InitializeSystem();

            SetEnvironmentBlendMode(options.get(), program.GetPreferredBlendMode());
            UpdateOptionsFromCommandLine(options.get(), argc, argv);
            platformPlugin->UpdateOptions(options);
            graphicsPlugin->UpdateOptions(options);

            program.InitializeDevice();
            program.InitializeSession();
            program.CreateSwapchains();

            while (!quitKeyPressed) {
                bool exitRenderLoop = false;
                program.PollEvents(&exitRenderLoop, &requestRestart);
                if (exitRenderLoop) {
                    break;
                }

                if (program.IsSessionRunning()) {
                    program.PollActions();
                    program.RenderFrame();
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
