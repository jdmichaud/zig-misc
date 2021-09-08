// zig build-exe -lc echo-client.zig
const std = @import("std");
const socket = @cImport({
  @cInclude("sys/types.h>");
  @cInclude("sys/socket.h>");
  @cInclude("sys/un.h>");
  @cInclude("stdio.h>");
});
const unistd = @cImport({
  @cInclude("unistd.h>");
});
const stdio = @cImport({
  @cInclude("stdio.h");
});

const protocol = @import("protocol.zig");

pub fn main() !void {
  const sockfd = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
  var addr = std.mem.zeroes(socket.sockaddr_un);
  addr.sun_family = socket.AF_UNIX;
  std.mem.copy(u8, addr.sun_path[0..], protocol.socketfile);

  if (socket.connect(sockfd, @ptrCast([*c] const socket.sockaddr, &addr), @sizeOf(socket.sockaddr_un)) != 0) {
    stdio.perror("connect");
    std.os.exit(1);
  }

  var messager = protocol.Messager.new(sockfd);
  const wd = protocol.WindowDescription { .width = 512, .height = 512 };
  try messager.send(protocol.Message { .WindowDescription = wd });
  const syncfiles = try messager.recv();
  const map = try protocol.create_map(wd, @ptrCast([*c]const u8, try std.heap.page_allocator.dupeZ(u8, syncfiles.SyncFiles.shmfile)));
  _ = map;
  try messager.send(protocol.Message { .Quit = .{ .reason = "" } });
}

