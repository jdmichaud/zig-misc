// zig build-exe -lc echo-server.zig
const std = @import("std");
const socket = @cImport({ 
  @cInclude("sys/types.h");
  @cInclude("sys/socket.h");
  @cInclude("sys/un.h");
  @cInclude("stdlib.h");
  @cInclude("unistd.h");
});
const stdio = @cImport({
  @cInclude("stdio.h");
});

const socket_path = "/tmp/echo-server";

pub fn main() !void {
  const sockfd = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
  
  var addr = std.mem.zeroes(socket.sockaddr_un);
  addr.sun_family = socket.AF_UNIX;
  std.mem.copy(u8, addr.sun_path[0..], socket_path);
  _ = socket.unlink(socket_path);
  if (socket.bind(sockfd, @ptrCast([*c] const socket.sockaddr, &addr), @sizeOf(socket.sockaddr_un)) < 0) {
    stdio.perror("bind");
    std.os.exit(1);
  }
  if (socket.listen(sockfd, 1) < 0) {
    stdio.perror("listen");
    std.os.exit(1);
  }

  var client_addr = std.mem.zeroes(socket.sockaddr_un);
  var client_addr_size: socket.socklen_t = 0;
  var client_fd: c_int = 0;
  while (true) {
    client_fd = socket.accept(sockfd, @ptrCast([*c] socket.sockaddr, &client_addr), &client_addr_size);
    if (client_fd < 0) {
      stdio.perror("accept");
      std.os.exit(1);
    }
    std.debug.print("connected to {}\n", .{ client_fd });
    var buffer: [255]u8 = [_]u8{0} ** 255;
    _ = socket.read(client_fd, @ptrCast(*c_void, &buffer), 255);
    _ = socket.write(client_fd, @ptrCast(*c_void, &buffer), 255);
    _ = socket.close(client_fd);
  } 
}

