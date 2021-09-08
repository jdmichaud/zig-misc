const std = @import("std");

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

pub const Quit = struct {
  reason: []u8,
};

pub const WindowDescription = struct {
  width: u32,
  height: u32,
};

pub const MouseMoveEvent = struct {
  clientX: i32,
  clientY: i32,
  movementX: i32,
  movementY: i32,
};

pub const SyncFiles = struct {
  shmfile: []const u8,
  semfile: []const u8,
};

pub const Message = union(enum) {
  Quit: Quit,
  WindowDescription: WindowDescription,
  MouseMoveEvent: MouseMoveEvent,
  SyncFiles: SyncFiles,
};

pub const socketfile = "/tmp/server";

pub const SocketWriter = struct {
  const Self = @This();
  pub const Writer = std.io.Writer(*Self, Error, write);
  pub const Error = error { WriterError };

  sockfd: c_int,

  pub fn new(sockfd: c_int) Self {
    return Self {
      .sockfd = sockfd,
    };
  }

  pub fn write(self: *Self, payload: []const u8) Error!usize {
    const bytewritten = unistd.write(self.sockfd, @ptrCast(* const c_void, payload), payload.len);
    if (bytewritten < 0) {
      return Self.Error.WriterError;
    }
    return @intCast(usize, bytewritten);
  }

  pub fn writeAll(self: *Self, payload: []const u8) Error!void {
    const network_len = arpa.htonl(@intCast(u32, payload.len)); // 2^32 bytes is enough for everyone.
    const payload_size: []const u8 = std.mem.asBytes(&network_len);
    std.debug.assert((try self.write(payload_size)) == 4);
    var index: usize = 0;
    while (index < payload.len) {
      index += try self.write(payload[index..]);
    }
  }

};

pub const Messager = struct {
  const Self = @This();

  sockfd: c_int,

  pub fn new(sockfd: c_int) Messager {
    return Messager {
      .sockfd = sockfd,
    };
  }

  pub fn send(self: *Self, message: Message) !void {
    std.debug.print("<-- {d}\n", .{ message });
    var writer = std.io.bufferedWriter(SocketWriter.new(self.sockfd));
    try std.json.stringify(message, std.json.StringifyOptions {}, writer.writer());
    try writer.flush();
  }

  fn fullread(fd: c_int, buffer: []u8, size: usize) !isize {
    var totalread: isize = 0;
    while (totalread < size) {
      const utotalread = @intCast(usize, totalread);
      const byteread = unistd.read(fd, @ptrCast(*c_void, &buffer[utotalread]), size - utotalread);
      std.debug.print("byteread {}\n", .{ byteread });
      if (byteread < 0) {
        return error.ReadError;
      }
      if (byteread == 0) {
        return error.EndOfFile;
      }
      totalread += byteread;
    }
    return totalread;
  }

  pub fn recv(self: Self) !Message {
    // First a 4 byte payload containing the size of the incoming message
    var buffer: [4096]u8 = [_]u8{0} ** 4096;
    std.debug.assert((try fullread(self.sockfd, buffer[0..], @sizeOf(u32))) == 4);
    const message_length_n: u32 = buffer[0] | @intCast(u32, buffer[1]) << 8 | @intCast(u32, buffer[2]) << 18 | @intCast(u32, buffer[3]) << 24;
    const message_length = arpa.ntohl(message_length_n);
    std.debug.assert(message_length < 4096);
    // Then read the full message
    const byteread = try fullread(self.sockfd, buffer[0..], message_length);
    std.debug.assert(byteread == message_length);
    // std.debug.print("recv: {s}\n", .{ buffer });
    const ops = std.json.ParseOptions {
      .allocator = std.heap.page_allocator,
      .ignore_unknown_fields = true,
      .allow_trailing_data = true,
    };
    // The message is supposed to be a protocol.Message encoded in Json
    const message = try std.json.parse(Message, &std.json.TokenStream.init(buffer[0..]), ops);
    defer std.json.parseFree(Message, message, ops);
    std.debug.print("--> {s}\n", .{ message });
    return message;
  }

};

pub const Map = struct {
  shfd: c_int,
  ptr: *c_void,
  bytemap: [*]u8,
  size: u32,
  shmfile: [*c]const u8,
}; 

pub fn create_map(windowDescription: WindowDescription, shmfile: [*c]const u8) !Map {
  var shfd = shm.shm_open(shmfile, shm.O_RDWR, shm.S_IRUSR | shm.S_IWUSR);
  if (shfd <= 0) {
    // Create a shared memory object
    shfd = shm.shm_open(shmfile, shm.O_CREAT | shm.O_RDWR, shm.S_IRUSR | shm.S_IWUSR);
  }
  errdefer {
    _ = unistd.close(shfd);
    _ = shm.shm_unlink(shmfile);
  }
  const size = windowDescription.width * windowDescription.height;
  if (shfd <= 0) return error.shmOpen;
  if (unistd.ftruncate(shfd, size) != 0) return error.truncate;
  // Map the object to local memory
  var map = mmap.mmap(null, size, mmap.PROT_READ | mmap.PROT_WRITE, mmap.MAP_SHARED, shfd, 0) orelse unreachable;
  errdefer _ = mmap.munmap(map, size);
  if (map == mmap.MAP_FAILED) return error.mmap;
  var bytemap = @ptrCast([*]u8, map);

  return Map {
    .shfd = shfd,
    .ptr = map,
    .bytemap = bytemap,
    .size = size,
    .shmfile = shmfile,
  };
}

pub fn close_map(map: Map) void {
  _ = unistd.close(map.shfd);
  _ = shm.shm_unlink(map.shmfile);
  _ = mmap.munmap(map.ptr, map.size);
}

