const std = @import("std");
const math = std.math;
const vec_t: type = @Vector(16, f32);

const K_D0: f32 = 0.0037930734;
const K_D1: f32 = std.math.lossyCast(f32, math.cbrt(@as(f32, K_D0)));

const V00: vec_t = @splat(@as(f32, 0.0));
const V05: vec_t = @splat(@as(f32, 0.5));
const V10: vec_t = @splat(@as(f32, 1.0));
const V11: vec_t = @splat(@as(f32, 1.1));

const V001: vec_t = @splat(@as(f32, 0.01));
const V005: vec_t = @splat(@as(f32, 0.05));
const V055: vec_t = @splat(@as(f32, 0.55));
const V042: vec_t = @splat(@as(f32, 0.42));
const V140: vec_t = @splat(@as(f32, 14.0));

const K_M02: vec_t = @splat(@as(f32, 0.078));
const K_M00: vec_t = @splat(@as(f32, 0.30));
const K_M01: vec_t = V10 - K_M02 - K_M00;

const K_M12: vec_t = @splat(@as(f32, 0.078));
const K_M10: vec_t = @splat(@as(f32, 0.23));
const K_M11: vec_t = V10 - K_M12 - K_M10;

const K_M20: vec_t = @splat(@as(f32, 0.24342269));
const K_M21: vec_t = @splat(@as(f32, 0.20476745));
const K_M22: vec_t = V10 - K_M20 - K_M21;

const OPSIN_ABSORBANCE_MATRIX = [_]vec_t{ K_M00, K_M01, K_M02, K_M10, K_M11, K_M12, K_M20, K_M21, K_M22 };
const OPSIN_ABSORBANCE_BIAS: vec_t = @splat(K_D0);
const ABSORBANCE_BIAS: vec_t = @splat(-K_D1);

inline fn cbrt_vec(x: vec_t) vec_t {
    var out: vec_t = undefined;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        out[i] = std.math.lossyCast(f32, math.cbrt(@as(f32, x[i])));
    }

    return out;
}

inline fn mixed_to_xyb(mixed: [3]vec_t) [3]vec_t {
    var out: [3]vec_t = undefined;
    out[0] = V05 * (mixed[0] - mixed[1]);
    out[1] = V05 * (mixed[0] + mixed[1]);
    out[2] = mixed[2];
    return out;
}

inline fn opsin_absorbance(rgb: [3]vec_t) [3]vec_t {
    var out: [3]vec_t = undefined;
    out[0] = @mulAdd(
        vec_t,
        OPSIN_ABSORBANCE_MATRIX[0],
        rgb[0],
        @mulAdd(
            vec_t,
            OPSIN_ABSORBANCE_MATRIX[1],
            rgb[1],
            @mulAdd(
                vec_t,
                OPSIN_ABSORBANCE_MATRIX[2],
                rgb[2],
                OPSIN_ABSORBANCE_BIAS,
            ),
        ),
    );

    out[1] = @mulAdd(
        vec_t,
        OPSIN_ABSORBANCE_MATRIX[3],
        rgb[0],
        @mulAdd(
            vec_t,
            OPSIN_ABSORBANCE_MATRIX[4],
            rgb[1],
            @mulAdd(
                vec_t,
                OPSIN_ABSORBANCE_MATRIX[5],
                rgb[2],
                OPSIN_ABSORBANCE_BIAS,
            ),
        ),
    );

    out[2] = @mulAdd(
        vec_t,
        OPSIN_ABSORBANCE_MATRIX[6],
        rgb[0],
        @mulAdd(
            vec_t,
            OPSIN_ABSORBANCE_MATRIX[7],
            rgb[1],
            @mulAdd(
                vec_t,
                OPSIN_ABSORBANCE_MATRIX[8],
                rgb[2],
                OPSIN_ABSORBANCE_BIAS,
            ),
        ),
    );

    return out;
}

inline fn linear_rgb_to_xyb(input: [3]vec_t) [3]vec_t {
    var mixed: [3]vec_t = opsin_absorbance(input);

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const pred: @Vector(16, bool) = mixed[i] < V00;
        mixed[i] = @select(f32, pred, V00, mixed[i]);
        mixed[i] = cbrt_vec(mixed[i]) + ABSORBANCE_BIAS;
    }

    mixed = mixed_to_xyb(mixed);
    return mixed;
}

inline fn make_positive_xyb(xyb: *[3]vec_t) void {
    xyb[2] += V11 - xyb[1];
    xyb[0] += V05;
    xyb[1] += V005;
}

inline fn process_vec(src: [3][]const f32, dst: [3][]f32) void {
    var out: [3]vec_t = undefined;
    var rgb = [3]vec_t{
        src[0][0..16].*,
        src[1][0..16].*,
        src[2][0..16].*,
    };

    out = linear_rgb_to_xyb(rgb);
    make_positive_xyb(&out);

    for (dst, 0..) |p, i| {
        p[0..16].* = out[i];
    }
}

pub inline fn process(_srcp: [3][*]const f32, _dstp: [3][*]f32, stride: usize, width: usize, height: usize) void {
    var srcp = _srcp;
    var dstp = _dstp;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 16) {
            const x2: usize = x + 16;
            var srcps = [3][]const f32{
                srcp[0][x..x2],
                srcp[1][x..x2],
                srcp[2][x..x2],
            };

            var dstps = [3][]f32{
                dstp[0][x..x2],
                dstp[1][x..x2],
                dstp[2][x..x2],
            };

            process_vec(srcps, dstps);
        }

        var i: usize = 0;
        while (i < 3) : (i += 1) {
            srcp[i] += stride;
            dstp[i] += stride;
        }
    }
}
