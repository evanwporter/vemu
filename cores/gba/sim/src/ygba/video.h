// Copyright (c) 2021 Ridge Shrubsall
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <stdint.h>

#define SCREEN_WIDTH    240
#define SCREEN_HEIGHT   160

#define NUM_SCANLINES   (SCREEN_HEIGHT + 68)

#define CYCLES_HDRAW    1006
#define CYCLES_HBLANK   226
#define CYCLES_SCANLINE (CYCLES_HDRAW + CYCLES_HBLANK)     // 1232
#define CYCLES_VDRAW    (CYCLES_SCANLINE * SCREEN_HEIGHT)  // 197120
#define CYCLES_VBLANK   (CYCLES_SCANLINE * 68)             // 83776
#define CYCLES_FRAME    (CYCLES_VDRAW + CYCLES_VBLANK)     // 280896

#define DCNT_GB       (1 << 3)
#define DCNT_PAGE     (1 << 4)
#define DCNT_OAM_HBL  (1 << 5)
#define DCNT_OBJ_1D   (1 << 6)
#define DCNT_BLANK    (1 << 7)
#define DCNT_BG0      (1 << 8)
#define DCNT_BG1      (1 << 9)
#define DCNT_BG2      (1 << 10)
#define DCNT_BG3      (1 << 11)
#define DCNT_OBJ      (1 << 12)
#define DCNT_WIN0     (1 << 13)
#define DCNT_WIN1     (1 << 14)
#define DCNT_WINOBJ   (1 << 15)

#define DSTAT_IN_VBL  (1 << 0)
#define DSTAT_IN_HBL  (1 << 1)
#define DSTAT_IN_VCT  (1 << 2)
#define DSTAT_VBL_IRQ (1 << 3)
#define DSTAT_HBL_IRQ (1 << 4)
#define DSTAT_VCT_IRQ (1 << 5)

void video_render_frame(const uint32_t* registers,
    const uint8_t* palette,
    const uint8_t* vram,
    const uint8_t* oam,
    uint32_t* framebuffer);
