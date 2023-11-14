const vec_t: type = @Vector(16, f32);

inline fn process_vec(src1: anytype, src2: anytype, dst: []f32) void {
    dst[0..16].* = @as(vec_t, src1[0..16].*) * @as(vec_t, src2[0..16].*);
}

pub inline fn process(src1: [*]const f32, src2: [*]const f32, dst: [*]f32, stride: usize, width: usize, height: usize) void {
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var srcp1 = src1 + y * stride;
        var srcp2 = src2 + y * stride;
        var dstp = dst + y * stride;
        var x: usize = 0;
        while (x < width) : (x += 16) {
            const x2: usize = x + 16;
            process_vec(srcp1[x..x2], srcp2[x..x2], dstp[x..x2]);
        }
    }
}
