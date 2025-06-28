
const std = @import("std");

pub fn main() !void{
  // 1750661824553752
  // 1749701101897989
    const a = std.heap.page_allocator;
    const time = std.time.microTimestamp();
    const time_str = try std.fmt.allocPrint(a, "{d}", .{time});
    defer a.free(time_str);

    const new_str = try std.mem.replaceOwned(u8, a, "hello world world", "orl", time_str);
    defer a.free(new_str);

    std.debug.print("{s}", .{new_str});


}

const json = std.json;
test "base64" {
  //  const allocator = std.testing.allocator;
  var buffer: [25] u8 = undefined;
  const source = "AAAAAaBoW4l2UmamyJ04YkZYmSYDcwBGzg";
  // const len = try std.base64.standard_no_pad.Decoder.calcSizeForSlice(source);
  try std.base64.standard_no_pad.Decoder.decode(&buffer, source);
  for(buffer)|b| {
    std.debug.print("{x:0>2}_", .{b});
  }
  std.debug.print("len_{d}\n", .{buffer.len});
}

test "type" {
  //  const allocator = std.testing.allocator;
  const Mytype = struct { 
    array: [10] u8 = @splat('b'),
    array_2: [10] u8 = .{'c'} ** 10,
  };


  const a = Mytype{};
  std.debug.print("works good, {s}\n", .{&a.array});
  std.debug.print("works good, {s}\n", .{&a.array_2});
}