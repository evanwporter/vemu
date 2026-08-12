// Code taken w/ modifications from https://github.com/RidgeX/ygba
// Copyright (c) 2021 Ridge Shrubsall
// SPDX-License-Identifier: BSD-3-Clause

#include "gpu.hpp"
#include "gba.hpp"
#include <iostream>

#define BIT(x, i) (((x) >> (i)) & 1)
#define BITS(x, i, j) (((x) >> (i)) & ((1 << ((j) - (i) + 1)) - 1))

#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 160

static u32 rgb555_to_rgb888(u16 pixel) {
    int red = BITS(pixel, 0, 4);
    int green = BITS(pixel, 5, 9);
    int blue = BITS(pixel, 10, 14);

    red = (red << 3) | (red >> 2);
    green = (green << 3) | (green >> 2);
    blue = (blue << 3) | (blue >> 2);

    return 0xff << 24 | blue << 16 | green << 8 | red;
}

static bool read_bitmap_pixel(GameboyAdvanceHarness& gba, int x, int y, int mode, u16& out) {
    auto vram = gba.get_top().rootp->GameboyAdvance__DOT__ppu__DOT__VRAM__DOT__mem;

    int w = (mode == 5 ? 160 : 240);
    int h = (mode == 5 ? 128 : 160);

    if (x >= w || y >= h)
        return false;

    if (mode == 3) {
        u32 addr = (y * 240 + x) * 2;
        out = *(u16*)&vram[addr];
        return true;
    }

    if (mode == 4) {
        bool page = (gba.read_memory(0x04000000) & 0x10); // DISPCNT bit 4
        u32 base = page ? 0xA000 : 0x0000;

        uint8_t index = vram[base + y * 240 + x];
        if (index == 0)
            return false;

        auto palette = gba.get_top().rootp->GameboyAdvance__DOT__Palette__DOT__mem;
        out = *(u16*)&palette[index * 2];
        return true;
    }

    if (mode == 5) {
        bool page = (gba.read_memory(0x04000000) & 0x10);
        u32 base = page ? 0xA000 : 0x0000;

        u32 addr = base + (y * 160 + x) * 2;
        out = *(u16*)&vram[addr];
        return true;
    }

    return false;
}

void render_frame(GameboyAdvanceHarness& gba, u32 framebuffer[160][240]) {

    int mode = gba.read_memory(0x04000000) & 0x7; // DISPCNT

    for (int y = 0; y < 160; y++) {
        for (int x = 0; x < 240; x++) {
            u16 pixel;

            if (read_bitmap_pixel(gba, x, y, mode, pixel)) {
                framebuffer[y][x] = rgb555_to_rgb888(pixel);
            } else {
                framebuffer[y][x] = 0xFF000000; // black
            }
        }
    }
}

#include <SDL2/SDL.h>
#include <cstdint>

class SDLDisplay {
public:
    static constexpr int WIDTH = 240;
    static constexpr int HEIGHT = 160;

    bool init(int scale = 3) {
        if (SDL_Init(SDL_INIT_VIDEO) != 0) {
            return false;
        }

        window = SDL_CreateWindow(
            "GBA",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            WIDTH * scale,
            HEIGHT * scale,
            0);

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

        texture = SDL_CreateTexture(
            renderer,
            SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING,
            WIDTH,
            HEIGHT);

        return window && renderer && texture;
    }

    void draw(uint32_t framebuffer[HEIGHT][WIDTH]) {
        SDL_UpdateTexture(texture, nullptr, framebuffer, WIDTH * sizeof(uint32_t));

        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
    }

    bool process_events() {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT)
                return false;
        }
        return true;
    }

    ~SDLDisplay() {
        if (texture)
            SDL_DestroyTexture(texture);
        if (renderer)
            SDL_DestroyRenderer(renderer);
        if (window)
            SDL_DestroyWindow(window);
        SDL_Quit();
    }

private:
    SDL_Window* window = nullptr;
    SDL_Renderer* renderer = nullptr;
    SDL_Texture* texture = nullptr;
};

void run_with_display(GameboyAdvanceHarness& gba) {
    const int WIDTH = 240;
    const int HEIGHT = 160;
    const int SCALE = 3;
    const int CYCLES_PER_FRAME = 280896;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "SDL init failed\n";
        return;
    }

    SDL_Window* window = SDL_CreateWindow(
        "GBA",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        WIDTH * SCALE,
        HEIGHT * SCALE,
        0);

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_Texture* texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        WIDTH,
        HEIGHT);

    if (!window || !renderer || !texture) {
        std::cerr << "SDL setup failed\n";
        return;
    }

    uint32_t framebuffer[HEIGHT][WIDTH];
    int cycle_counter = 0;
    bool running = true;

    while (running) {
        // --- Handle events ---
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                running = false;
            }
        }

        // --- Run emulation ---
        gba.tick();
        cycle_counter++;

        // --- Render once per frame ---
        if (cycle_counter >= CYCLES_PER_FRAME) {
            cycle_counter = 0;

            render_frame(gba, framebuffer);

            SDL_UpdateTexture(texture, nullptr, framebuffer, WIDTH * sizeof(uint32_t));

            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, nullptr, nullptr);
            SDL_RenderPresent(renderer);

            // Optional: cap to ~60 FPS
            SDL_Delay(16);
        }
    }

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
}
