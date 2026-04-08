#pragma once

#include "gba.hpp"

void render_frame(GameboyAdvanceHarness& gba, u32 framebuffer[160][240]);

void run_with_display(GameboyAdvanceHarness& gba);