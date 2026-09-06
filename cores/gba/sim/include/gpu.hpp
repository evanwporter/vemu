#pragma once

#include "gba.hpp"

void render_ppu_frame(GameboyAdvanceHarness& gba, u32 framebuffer[160][240]);
