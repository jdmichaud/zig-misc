// zig build-exe -lc echo-client.zig
const std = @import("std");
const socket = @cImport({
  @cInclude("sys/types.h>");
  @cInclude("sys/socket.h>");
  @cInclude("sys/un.h>");
  @cInclude("unistd.h>");
  @cInclude("stdio.h>");
});
const stdio = @cImport({
  @cInclude("stdio.h");
});

const socketfile = "/tmp/echo-server";

pub fn main() !void {
  const sockfd = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
  var addr = std.mem.zeroes(socket.sockaddr_un);
  addr.sun_family = socket.AF_UNIX;
  std.mem.copy(u8, addr.sun_path[0..], socketfile);

  if (socket.connect(sockfd, @ptrCast([*c] const socket.sockaddr, &addr), @sizeOf(socket.sockaddr_un)) != 0) {
    stdio.perror("connect");
    std.os.exit(1);
  }

  _ = socket.write(sockfd, "Hello\n", 7);
  var buffer: [255]u8 = [_]u8{0} ** 255;
  _ = socket.read(sockfd, @ptrCast(*c_void, &buffer), 255);
  std.debug.print("resp: {s}", .{ buffer });
}

