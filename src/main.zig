const std = @import("std");
const stbi = @import("stb_image.zig");

const c = @cImport(@cInclude("SDL2/SDL.h"));

pub fn main() !void {
    var arg_it = std.process.args();
    const argv0 = arg_it.next();

    const image_path = arg_it.next() orelse {
        std.debug.print("Usage: {?s} <file>\n", .{argv0});
        return;
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    stbi.setAllocator(arena.allocator());

    const image = stbi.load(image_path) catch |err| {
        std.debug.print("error: stbi.load: {s}\n", .{stbi.failure_reason()});
        return err;
    };
    defer image.deinit();

    std.debug.print("Image loaded successfully\n", .{});
    std.debug.print(
        "width: {}\nheight: {}\nchannels: {}\n",
        .{ image.width, image.height, image.channels },
    );

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "life",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        image.width,
        image.height,
        c.SDL_WINDOW_OPENGL,
    ) orelse {
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, 0) orelse {
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    // NOTE: set to false to render window
    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => quit = true,
                else => {},
            }
        }
        _ = c.SDL_RenderClear(renderer);

        for (0..@intCast(image.height)) |i| {
            const dpos = i * @as(usize, @intCast(image.width));
            for (0..@intCast(image.width)) |j| {
                const pixel = image.getPixel(j + dpos);
                _ = c.SDL_SetRenderDrawColor(renderer, pixel[0], pixel[1], pixel[2], if (image.channels == 4) pixel[3] else 255);
                _ = c.SDL_RenderDrawPoint(renderer, @intCast(j), @intCast(i));
            }
        }

        c.SDL_RenderPresent(renderer);
    }
}

// fn pixelSort(image: stbi.Image) void {
//     // const pixels: []u24 = @ptrCast(data);
//     var pixels: []u24 = undefined;
//     pixels.len = image.data.len / 3;
//
//     for (0..pixels.len - 2) |i| {
//         if (pixels[i] > pixels[i + 1]) {
//             std.mem.swap(u24, &pixels[i], &pixels[i + 1]);
//         }
//     }
// }
