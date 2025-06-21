//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

pub const random = std.crypto.random;
pub fn generateUniqueId(allocator: std.mem.Allocator,len: u8) ![]const u8 {
    const charset: [] const u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    const charset_len = charset.len;

    const buffer = try allocator.alloc(u8, len);
    errdefer allocator.free(buffer);
    for (buffer) |*b| {
        const idx = random.int(u8) % charset_len;
        b.* = charset[idx];
    }

    return buffer;
}

test "random" {
}
