// zig build-exe -lc echo-client.zig
const std = @import("std");
const socket = @cImport({
  @cInclude("sys/types.h>");
  @cInclude("sys/socket.h>");
  @cInclude("sys/un.h>");
});
const unistd = @cImport({
  @cInclude("unistd.h>");
});
const arpa = @cImport({
  @cInclude("arpa/inet.h");
});
const shm = @cImport({
  @cInclude("sys/mman.h>");
  @cInclude("sys/stat.h>"); // For mode constants
  @cInclude("fcntl.h>");    // For O_* constants
});
const mmap = @cImport({
  @cInclude("sys/mman.h");
});
const stdio = @cImport({
  @cInclude("stdio.h");
});

const protocol = @import("protocol.zig");

const socketfile = "/tmp/server";
const shmfile = "/shmfile";

pub fn errExit(status: bool, fname: []const u8) !void {
  if (!status) {
    stdio.perror(@ptrCast([*c] const u8, fname));
    return error.Error;
  }
}

pub fn fullread(fd: c_int, buffer: []u8, size: usize) !isize {
  var totalread: isize = 0;
  while (totalread < size) {
    const utotalread = @intCast(usize, totalread);
    const byteread = unistd.read(fd, @ptrCast(*c_void, &buffer[utotalread]), size - utotalread);
    if (byteread < 0) {
      return error.ReadError;
    }
    totalread += byteread;
  }
  return totalread;
}

pub fn main() !void {
  // Open a unix socket
  const sockfd = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
  defer _ = unistd.close(sockfd);
  try errExit(sockfd > 0, "socket");
  var addr = std.mem.zeroes(socket.sockaddr_un);
  addr.sun_family = socket.AF_UNIX;
  std.mem.copy(u8, addr.sun_path[0..], socketfile);
  _ = unistd.unlink(socketfile);
  try errExit(socket.bind(sockfd, @ptrCast([*c] const socket.sockaddr, &addr), @sizeOf(socket.sockaddr_un)) == 0, "bind");
  try errExit(socket.listen(sockfd, 1) == 0, "listen");
  // Wait for client connection
  var client_addr = std.mem.zeroes(socket.sockaddr_un);
  var client_addr_size: socket.socklen_t = 0;
  var clientfd: c_int = 0;

  while (true) {
    clientfd = socket.accept(sockfd, @ptrCast([*c] socket.sockaddr, &client_addr), &client_addr_size);
    try errExit(clientfd >= 0, "accept");
    std.debug.print("connected to client {}\n", .{ clientfd });
    var messager = protocol.Messager.new(clientfd);

    var map: protocol.Map = undefined;
    while (true) {
      std.debug.print("listening to client {}\n", .{ clientfd });
      const message = messager.recv() catch |err| {
        if (err == error.EndOfFile) {
          _ = unistd.close(clientfd);
          break;
        }
        return err;
      };

      switch (message) {
        protocol.Message.WindowDescription => |wd| {
          map = try protocol.create_map(wd, shmfile);
          try messager.send(protocol.Message { .SyncFiles = .{ .shmfile = shmfile, .semfile = "" } });
        },
        protocol.Message.Quit => {
          _ = unistd.close(clientfd);
          protocol.close_map(map);
          break;
        },
        else => {},
      }
    }
  } 
}

