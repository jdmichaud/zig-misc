// zig build-exe -lc shared-memory.zig
const std = @import("std");
const shm = @cImport({
  @cInclude("sys/mman.h>");
  @cInclude("sys/stat.h>"); // For mode constants
  @cInclude("fcntl.h>");    // For O_* constants
});
const unistd = @cImport({
  @cInclude("unistd.h");
  @cInclude("sys/types.h");
});
const mmap = @cImport({
  @cInclude("sys/mman.h");
});
const semaphore = @cImport({
  @cInclude("semaphore.h");
});
const stdio = @cImport({
  @cInclude("stdio.h");
});

const shared_file = "/shared_file";
const shared_file_size = 10;

const semaphore_file = "/sync";

pub fn errExit(status: bool, fname: []const u8) void {
  if (!status) {
    stdio.perror(@ptrCast([*c] const u8, fname));
    std.os.exit(1);
  }
}

pub fn main() !void {
  // Open a shared memory object if it already exists
  var first = false;
  var shfd = shm.shm_open(shared_file, shm.O_RDWR, shm.S_IRUSR | shm.S_IWUSR);
  if (shfd <= 0) {
    first = true;
    // Create a shared memory object
    shfd = shm.shm_open(shared_file, shm.O_CREAT | shm.O_RDWR, shm.S_IRUSR | shm.S_IWUSR);
  }
  defer {
    errExit(unistd.close(shfd) == 0, "close");
    errExit(shm.shm_unlink(shared_file) == 0, "unlink");
    std.debug.print("unlink {s}\n", .{ shared_file });
  }
  errExit(shfd > 0, "shm_open");
  errExit(unistd.ftruncate(shfd, shared_file_size) == 0, "ftruncate");
  // Map the object to local memory
  var map = mmap.mmap(null, shared_file_size, mmap.PROT_READ | mmap.PROT_WRITE, mmap.MAP_SHARED, shfd, 0);
  defer errExit(mmap.munmap(map, shared_file_size) == 0, "munmap");
  errExit(map != mmap.MAP_FAILED, "mmap");
  // errExit(unistd.close(shfd) == 0, "close");
  var bytemap = @ptrCast([*]u8, map);
  // Initialize semaphore
  var semfd = semaphore.sem_open(semaphore_file, shm.O_CREAT, shm.S_IRUSR | shm.S_IWUSR, @intCast(c_int, 0));
  errExit(semfd != semaphore.SEM_FAILED, "sem_open");
  defer {
    errExit(semaphore.sem_close(semfd) == 0, "sem_close");
    errExit(semaphore.sem_unlink(semaphore_file) == 0, "sem_unlink");
  }
  // Initialize the map if first run
  std.debug.print("bytemap[1] {}\n", .{ bytemap[1] });
  if (first) {
    var i: u8 = 0;
    while (i < shared_file_size): (i += 1) {
      bytemap[i] = i;
      std.debug.print("bytemap[{}] {}\n", .{ i, bytemap[i] });
    }
    // return;
    // errExit(mmap.msync(map, shared_file_size, mmap.MS_SYNC) == 0, "msync");
  } else {
    std.debug.print("post\n", .{});
    errExit(semaphore.sem_post(semfd) == 0, "sem_post");
    _ = unistd.sleep(1);
  }
  while (true) {
    std.debug.print("wait\n", .{});
    errExit(semaphore.sem_wait(semfd) == 0, "sem_wait");
    var i: u8 = 0;
    while (i < shared_file_size): (i += 1) {
      std.debug.print("{}", .{ bytemap[i] });
      bytemap[i] = (bytemap[i] + 1) % shared_file_size;
    }
    // errExit(mmap.msync(map, shared_file_size, mmap.MS_SYNC) == 0, "msync");
    std.debug.print("\n", .{});
    std.debug.print("post\n", .{});
    errExit(semaphore.sem_post(semfd) == 0, "sem_post");
    _ = unistd.sleep(1);
  }
}

