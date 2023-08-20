const std = @import("std");

const Cpu = @import("./cpu.zig");

fn cpuPtrCast(in: anytype) switch (@TypeOf(in)) {
    ?*anyopaque => *Cpu,
    ?*const anyopaque => *const Cpu,
    else => unreachable,
} {
    return @ptrCast(@alignCast(in.?));
}

export fn chip8GetErrorName(err: u16) callconv(.C) [*:0]const u8 {
    return @errorName(@errorFromInt(err));
}

export fn chip8CpuGetSize() callconv(.C) usize {
    return @sizeOf(Cpu);
}

export fn chip8CpuInit(
    err: ?*u16,
    cpu: ?*anyopaque,
    program: ?[*]const u8,
    program_len: usize,
    seed: u64,
) callconv(.C) c_int {
    cpuPtrCast(cpu).* = Cpu.init(program.?[0..program_len], seed) catch |e| {
        err.?.* = @intFromError(e);
        return 1;
    };
    return 0;
}

export fn chip8CpuCycle(err: ?*u16, cpu: ?*anyopaque) callconv(.C) c_int {
    cpuPtrCast(cpu).cycle() catch |e| {
        err.?.* = @intFromError(e);
        return 1;
    };
    return 0;
}

export fn chip8CpuSetKeys(cpu: ?*anyopaque, keys: u16) callconv(.C) void {
    var new_keys: [16]bool = undefined;
    for (&new_keys, 0..) |*key, i_usize| {
        const i: u4 = @intCast(i_usize);
        key.* = (keys >> i) & 1 != 0;
    }
    cpuPtrCast(cpu).setKeys(&new_keys);
}

export fn chip8CpuIsWaitingForKey(cpu: ?*const anyopaque) callconv(.C) bool {
    return cpuPtrCast(cpu).next_key_register != null;
}

export fn chip8CpuTimerTick(cpu: ?*anyopaque) callconv(.C) void {
    cpuPtrCast(cpu).timerTick();
}

export fn chip8CpuDisplayIsDirty(cpu: ?*const anyopaque) callconv(.C) bool {
    return cpuPtrCast(cpu).display_dirty;
}

export fn chip8CpuSetDisplayNotDirty(cpu: ?*anyopaque) callconv(.C) void {
    cpuPtrCast(cpu).display_dirty = false;
}

export fn chip8CpuGetDisplay(cpu: ?*const anyopaque) callconv(.C) [*]const u8 {
    return @ptrCast(&cpuPtrCast(cpu).display);
}

fn chip8CpuAlloc() callconv(.C) ?[*]u8 {
    return (std.heap.wasm_allocator.alignedAlloc(u8, @alignOf(Cpu), @sizeOf(Cpu)) catch return null).ptr;
}

fn wasmAlloc(n: usize) callconv(.C) ?[*]u8 {
    return (std.heap.wasm_allocator.alignedAlloc(u8, @import("builtin").target.maxIntAlignment(), n) catch return null).ptr;
}

comptime {
    if (@import("builtin").target.isWasm()) {
        @export(chip8CpuAlloc, .{ .name = "chip8CpuAlloc" });
        @export(wasmAlloc, .{ .name = "wasmAlloc" });
    }
}

test "C-compatible usage" {
    const cpu_buf = try std.testing.allocator.alignedAlloc(
        u8,
        @import("builtin").target.maxIntAlignment(),
        chip8CpuGetSize(),
    );
    defer std.testing.allocator.free(cpu_buf);
    var err: u16 = 0;

    const long_program: []const u8 = &(.{0} ** 3585);
    const valid_program: []const u8 = &.{
        // set some registers
        0x60, 0xff,
        0x61, 0x80,
        0x62, 0x23,
        // this one is invalid
        0xf3, 0x00,
    };

    try std.testing.expectEqual(@as(c_int, 1), chip8CpuInit(
        &err,
        cpu_buf.ptr,
        long_program.ptr,
        long_program.len,
        1337,
    ));
    try std.testing.expectEqualStrings("ProgramTooLong", std.mem.span(chip8GetErrorName(err)));

    // this program should work for 3 instructions and then hit invalid opcode
    try std.testing.expectEqual(@as(c_int, 0), chip8CpuInit(&err, cpu_buf.ptr, valid_program.ptr, valid_program.len, 1337));
    for (0..3) |_| {
        try std.testing.expectEqual(@as(c_int, 0), chip8CpuCycle(&err, cpu_buf.ptr));
    }
    try std.testing.expectEqual(@as(c_int, 1), chip8CpuCycle(&err, cpu_buf.ptr));
    try std.testing.expectEqualStrings("IllegalOpcode", std.mem.span(chip8GetErrorName(err)));
}