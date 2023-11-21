const std = @import("std");
const allocator = std.heap.c_allocator;

inline fn blur_h(srcp: anytype, dstp: [*]f32, kernel: [9]f32, width: usize) void {
    const ksize: usize = 9;
    const radius: usize = ksize >> 1;

    var j: usize = 0;
    while (j < @min(width, radius)) : (j += 1) {
        const dist_from_right: usize = width - 1 - j;
        var accum: f32 = 0.0;
        var k: usize = 0;
        while (k < radius) : (k += 1) {
            const idx: usize = if (j < radius - k) (@min(radius - k - j, width - 1)) else (j - radius + k);
            accum += kernel[k] * srcp[idx];
        }

        k = radius;
        while (k < ksize) : (k += 1) {
            const idx: usize = if (dist_from_right < k - radius) (j - @min(k - radius - dist_from_right, j)) else (j - radius + k);
            accum += kernel[k] * srcp[idx];
        }

        dstp[j] = accum;
    }

    j = radius;
    while (j < width - @min(width, radius)) : (j += 1) {
        var accum: f32 = 0.0;
        var k: usize = 0;
        while (k < ksize) : (k += 1) {
            accum += kernel[k] * srcp[j - radius + k];
        }

        dstp[j] = accum;
    }

    j = @max(radius, width - @min(width, radius));
    while (j < width) : (j += 1) {
        const dist_from_right: usize = width - 1 - j;
        var accum: f32 = 0.0;
        var k: usize = 0;
        while (k < radius) : (k += 1) {
            const idx: usize = if (j < radius - k) (@min(radius - k - j, width - 1)) else (j - radius + k);
            accum += kernel[k] * srcp[idx];
        }

        k = radius;
        while (k < ksize) : (k += 1) {
            const idx: usize = if (dist_from_right < k - radius) (j - @min(k - radius - dist_from_right, j)) else (j - radius + k);
            accum += kernel[k] * srcp[idx];
        }

        dstp[j] = accum;
    }
}

inline fn blur_v(src: anytype, dstp: [*]f32, kernel: [9]f32, width: usize) void {
    var j: usize = 0;
    while (j < width) : (j += 1) {
        var accum: f32 = 0.0;
        var k: usize = 0;
        while (k < 9) : (k += 1) {
            accum += kernel[k] * src[k][j];
        }

        dstp[j] = accum;
    }
}

pub inline fn process(src: [*]const f32, dst: [*]f32, stride: usize, width: usize, height: usize) void {
    const kernel = [9]f32{
        0.0076144188642501831054687500,
        0.0360749699175357818603515625,
        0.1095860823988914489746093750,
        0.2134445458650588989257812500,
        0.2665599882602691650390625000,
        0.2134445458650588989257812500,
        0.1095860823988914489746093750,
        0.0360749699175357818603515625,
        0.0076144188642501831054687500,
    };

    const ksize: usize = 9;
    const radius: usize = ksize >> 1;
    var i: usize = 0;
    while (i < height) : (i += 1) {
        var srcp: [9][*]const f32 = undefined;
        const dstp: [*]f32 = dst + i * stride;
        const dist_from_bottom: usize = height - 1 - i;

        const tmp_arr = allocator.alignedAlloc(f32, 32, width) catch unreachable;
        defer allocator.free(tmp_arr);
        const tmp: [*]f32 = tmp_arr.ptr;

        var k: usize = 0;
        while (k < radius) : (k += 1) {
            const row: usize = if (i < radius - k) (@min(radius - k - i, height - 1)) else (i - radius + k);
            srcp[k] = src + row * stride;
        }

        k = radius;
        while (k < ksize) : (k += 1) {
            const row: usize = if (dist_from_bottom < k - radius) (i - @min(k - radius - dist_from_bottom, i)) else (i - radius + k);
            srcp[k] = src + row * stride;
        }

        blur_v(srcp, tmp, kernel, width);
        blur_h(tmp, dstp, kernel, width);
    }
}
