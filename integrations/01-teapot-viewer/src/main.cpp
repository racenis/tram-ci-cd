// Teapot regression integration test.
// Identical to tram-template's main.cpp except main_loop dumps a screenshot
// at a configurable tick and exits.
//
// Extra CLI flags (consumed before Settings::Parse so framework sees a clean argv):
//     --out=PATH    capture filename    (default: regression_capture.png)
//     --tick=N      capture at tick N   (default: 300)

#include <framework/core.h>
#include <framework/logging.h>
#include <framework/ui.h>
#include <framework/gui.h>
#include <framework/async.h>
#include <framework/event.h>
#include <framework/message.h>
#include <framework/system.h>
#include <framework/worldcell.h>
#include <framework/language.h>
#include <framework/file.h>
#include <framework/path.h>
#include <framework/stats.h>
#include <framework/script.h>
#include <framework/loader.h>
#include <framework/settings.h>
#include <components/trigger.h>
#include <audio/audio.h>
#include <audio/sound.h>
#include <render/render.h>
#include <render/material.h>
#include <render/api.h>
#include <render/scene.h>
#include <physics/physics.h>
#include <physics/api.h>
#include <entities/player.h>
#include <entities/staticworldobject.h>
#include <entities/light.h>
#include <entities/crate.h>
#include <entities/marker.h>
#include <entities/trigger.h>
#include <entities/sound.h>
#include <entities/decoration.h>
#include <components/player.h>
#include <components/animation.h>
#include <components/controller.h>
#include <components/render.h>
#include <extensions/camera/camera.h>
#include <extensions/menu/menu.h>
#include <extensions/scripting/lua.h>
#include <extensions/kitchensink/kitchensink.h>
#include <extensions/kitchensink/entities.h>
#include <extensions/kitchensink/soundtable.h>
#include <platform/image.h>

#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <vector>

using namespace tram;
using namespace tram::UI;
using namespace tram::Render;
using namespace tram::Physics;
using namespace tram::Ext::Kitchensink;

static int capture_tick = 300;
static const char* capture_path = "regression_capture.png";
static bool capture_done = false;

void main_loop();

int main(int argc, const char** argv) {
    // Strip --out= / --tick= from argv before Settings::Parse sees it.
    std::vector<const char*> filtered;
    filtered.reserve(argc);
    filtered.push_back(argv[0]);
    for (int i = 1; i < argc; ++i) {
        if (std::strncmp(argv[i], "--out=", 6) == 0) {
            capture_path = argv[i] + 6;
        } else if (std::strncmp(argv[i], "--tick=", 7) == 0) {
            capture_tick = std::atoi(argv[i] + 7);
        } else {
            filtered.push_back(argv[i]);
        }
    }
    Settings::Parse(filtered.data(), (int)filtered.size());

    Light::Register();
    Crate::Register();
    Sound::Register();
    Decoration::Register();
    Trigger::Register();
    StaticWorldObject::Register();
    Ext::Kitchensink::Button::Register();

    Core::Init();
    UI::Init();
    Render::Init();
    Physics::Init();
    // Regression captures must be deterministic — zero loader threads forces
    // resource loads to happen on the main thread via LoadResourcesFromDisk().
    Async::Init(0);
    Audio::Init();
    GUI::Init();

    Ext::Menu::Init();
    Ext::Camera::Init();
    Ext::Kitchensink::Init();

    Ext::Scripting::Lua::Init();
    Script::Init();

    Material::LoadMaterialInfo("material");
    Language::Load("en");

    Script::LoadScript("init");

    while (!UI::ShouldExit() && !capture_done) {
        main_loop();
    }

    Ext::Scripting::Lua::Uninit();
    Async::Yeet();
    Audio::Uninit();
    UI::Uninit();
}

// capture_done lets main()'s loop unwind through the normal teardown — using
// std::exit() instead skipped Async::Yeet() and tripped
// "terminate called without an active exception".
static void CaptureAndFlagExit(const char* path) {
    int w = (int)UI::GetScreenWidth();
    int h = (int)UI::GetScreenHeight();
    std::vector<unsigned char> rgb(w * h * 3);
    Render::API::GetScreen((char*)rgb.data(), w, h);
    Platform::SaveImageToDisk(path, w, h, (const char*)rgb.data());
    capture_done = true;
}

void main_loop() {
    static int tick = 0;

    Core::Update();
    UI::Update();
    Physics::Update();

    GUI::Begin();
    Ext::Menu::Update();

    Event::Dispatch();
    Message::Dispatch();

    GUI::End();
    GUI::Update();

    // With threads=0 nothing else pulls files off disk for us. Drain the
    // queue fully each tick so dependency chains (model → material → texture)
    // settle in one pass rather than one link per frame.
    while (Async::GetWaitingResources() > 0) {
        Async::LoadResourcesFromDisk();
        Async::LoadResourcesFromMemory();
        Async::FinishResources();
    }

    Loader::Update();

    AnimationComponent::Update();
    ControllerComponent::Update();

    Ext::Camera::Update();

    Render::Render();

    // Capture BEFORE UI::EndFrame() — EndFrame swaps buffers, after which
    // glReadPixels would read the undefined post-swap back buffer.
    if (++tick == capture_tick) {
        CaptureAndFlagExit(capture_path);
    }

    UI::EndFrame();

    Stats::Collate();
}
