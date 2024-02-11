const std = @import("std");

var allocator: std.mem.Allocator = undefined;
pub fn setAllocator(a: std.mem.Allocator) void {
    allocator = a;
}

export fn customMalloc(size: c_ulong) ?*anyopaque {
    const buf = allocator.alloc(usize, @divFloor(size, @sizeOf(usize)) + 2) catch return null;
    buf[0] = buf.len;
    return buf.ptr + 1;
}

export fn customRealloc(ptr: ?*anyopaque, size: c_ulong) ?*anyopaque {
    const bufptr = @as([*]usize, @alignCast(@ptrCast(ptr orelse return customMalloc(size)))) - 1;

    var buf: []usize = undefined;
    buf.len = bufptr[0];
    buf.ptr = bufptr;

    buf = allocator.realloc(buf, @divFloor(size, @sizeOf(usize)) + 2) catch return null;
    buf[0] = buf.len;
    return buf.ptr + 1;
}

export fn customFree(ptr: ?*anyopaque) void {
    const bufptr = @as([*]usize, @alignCast(@ptrCast(ptr orelse return))) - 1;

    var buf: []u8 = undefined;
    buf.len = bufptr[0];
    buf.ptr = @ptrCast(bufptr);

    allocator.free(buf);
}

const c = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_NO_SIMD", {});
    @cDefine("STBI_FAILURE_USERMSG", {});
    @cDefine("STBI_NO_GIF", {});
    @cDefine("STBI_NO_HDR", {});
    @cDefine("STBI_NO_TGA", {}); // stbi__tga_test uses goto

    @cInclude("custom_allocator.h");
    @cDefine("STBI_MALLOC(size)", "customMalloc(size)");
    @cDefine("STBI_REALLOC(ptr, size)", "customRealloc(ptr, size)");
    @cDefine("STBI_FREE(ptr)", "customFree(ptr)");

    @cInclude("stb_image.h");
});

const Error = error{STBIError};

pub const Image = struct {
    data: []u8,
    width: i32,
    height: i32,
    channels: i32,

    const Self = @This();

    pub fn deinit(self: Self) void {
        c.STBI_FREE(self.data.ptr);
    }

    pub fn getPixel(self: Self, idx: usize) []u8 {
        const channels: usize = @intCast(self.channels);
        return self.data[idx * channels .. idx * channels + channels];
    }
};

pub fn load(image_path: []const u8) Error!Image {
    var width: c_int = 0;
    var height: c_int = 0;
    var channels_in_file: c_int = undefined;
    var image_data: [*c]u8 = c.stbi_load(@ptrCast(image_path), &width, &height, &channels_in_file, 0);

    return if (image_data != null)
        .{
            .data = image_data[0..@intCast(width * height * channels_in_file)],
            .width = width,
            .height = height,
            .channels = channels_in_file,
        }
    else
        error.STBIError;
}

pub fn failure_reason() []const u8 {
    return std.mem.span(c.stbi_failure_reason());
}
