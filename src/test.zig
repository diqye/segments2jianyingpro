
const std = @import("std");

pub fn main() !void{
    std.debug.print("{}\n", .{std.meta.eql("hello","hello")});
}

const json = std.json;
test "ss" {
//    const allocator = std.testing.allocator;
  const a1 : i64 = 1_000_000;
  const a2 : f16 = 2.3333;
  const a3 : i64  = @trunc(@as(f64,@floatFromInt(a1)) * @as(f64,a2)); 
  std.debug.print("{d}", .{a3});

}