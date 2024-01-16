const std = @import("std");
const ssimulacra2 = @import("ssimulacra2.zig");
const allocator = std.heap.c_allocator;

const vec_t = @Vector(16, f32);

inline fn v_pass(src: [*]const f32, dst: [*]f32, stride: usize, d: *ssimulacra2.Ssimulacra2Data, width: usize, height: usize) void {
    const big_n = d.radius;
    const mul_in_1: vec_t = @splat(d.mul_in[0]);
    const mul_in_3: vec_t = @splat(d.mul_in[4]);
    const mul_in_5: vec_t = @splat(d.mul_in[8]);
    const mul_prev_1: vec_t = @splat(d.mul_prev[0]);
    const mul_prev_3: vec_t = @splat(d.mul_prev[4]);
    const mul_prev_5: vec_t = @splat(d.mul_prev[8]);
    const mul_prev2_1: vec_t = @splat(d.mul_prev2[0]);
    const mul_prev2_3: vec_t = @splat(d.mul_prev2[4]);
    const mul_prev2_5: vec_t = @splat(d.mul_prev2[8]);
    const v00: vec_t = @splat(@as(f32, 0.0));

    const iheight: i32 = @intCast(height);

    var x: usize = 0;
    while (x < width) : (x += 16) {
        const srcp = src + x;
        var dstp = dst + x;
        var prev_1: vec_t = v00;
        var prev_3: vec_t = v00;
        var prev_5: vec_t = v00;
        var prev2_1: vec_t = v00;
        var prev2_3: vec_t = v00;
        var prev2_5: vec_t = v00;

        var n: i32 = -big_n + 1;
        while (n < iheight) : (n += 1) {
            const top: i32 = n - big_n - 1;
            const bot: i32 = n + big_n - 1;
            const top_val: vec_t = if (top >= 0) (srcp[(@as(usize, @intCast(top)) * stride)..][0..16].*) else v00;
            const bot_val: vec_t = if (bot < iheight) (srcp[(@as(usize, @intCast(bot)) * stride)..][0..16].*) else v00;
            const sum: vec_t = top_val + bot_val;

            var out_1: vec_t = sum * mul_in_1;
            var out_3: vec_t = sum * mul_in_3;
            var out_5: vec_t = sum * mul_in_5;

            out_1 = @mulAdd(vec_t, mul_prev2_1, prev2_1, out_1);
            out_3 = @mulAdd(vec_t, mul_prev2_3, prev2_3, out_3);
            out_5 = @mulAdd(vec_t, mul_prev2_5, prev2_5, out_5);
            prev2_1 = prev_1;
            prev2_3 = prev_3;
            prev2_5 = prev_5;

            out_1 = @mulAdd(vec_t, mul_prev_1, prev_1, out_1);
            out_3 = @mulAdd(vec_t, mul_prev_3, prev_3, out_3);
            out_5 = @mulAdd(vec_t, mul_prev_5, prev_5, out_5);
            prev_1 = out_1;
            prev_3 = out_3;
            prev_5 = out_5;

            if (n >= 0) {
                dstp[(@as(usize, @intCast(n)) * stride)..][0..16].* = out_1 + out_3 + out_5;
            }
        }
    }
}

inline fn h_pass(src: [*]const f32, dst: [*]f32, stride: usize, d: *ssimulacra2.Ssimulacra2Data, width: usize, height: usize) void {
    const big_n = d.radius;
    const mul_in_1 = d.mul_in[0];
    const mul_in_3 = d.mul_in[4];
    const mul_in_5 = d.mul_in[8];
    const mul_prev_1 = d.mul_prev[0];
    const mul_prev_3 = d.mul_prev[4];
    const mul_prev_5 = d.mul_prev[8];
    const mul_prev2_1 = d.mul_prev2[0];
    const mul_prev2_3 = d.mul_prev2[4];
    const mul_prev2_5 = d.mul_prev2[8];

    const iwidth: i32 = @intCast(width);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        const srcp = src + y * stride;
        var dstp = dst + y * stride;
        var prev_1: f32 = 0.0;
        var prev_3: f32 = 0.0;
        var prev_5: f32 = 0.0;
        var prev2_1: f32 = 0.0;
        var prev2_3: f32 = 0.0;
        var prev2_5: f32 = 0.0;

        var n: i32 = -big_n + 1;
        while (n < iwidth) : (n += 1) {
            const left: i32 = n - big_n - 1;
            const right: i32 = n + big_n - 1;
            const left_val: f32 = if (left >= 0) (srcp[@intCast(left)]) else 0.0;
            const right_val: f32 = if (right < iwidth) (srcp[@intCast(right)]) else 0.0;
            const sum: f32 = left_val + right_val;

            var out_1: f32 = sum * mul_in_1;
            var out_3: f32 = sum * mul_in_3;
            var out_5: f32 = sum * mul_in_5;

            out_1 = @mulAdd(f32, mul_prev2_1, prev2_1, out_1);
            out_3 = @mulAdd(f32, mul_prev2_3, prev2_3, out_3);
            out_5 = @mulAdd(f32, mul_prev2_5, prev2_5, out_5);
            prev2_1 = prev_1;
            prev2_3 = prev_3;
            prev2_5 = prev_5;

            out_1 = @mulAdd(f32, mul_prev_1, prev_1, out_1);
            out_3 = @mulAdd(f32, mul_prev_3, prev_3, out_3);
            out_5 = @mulAdd(f32, mul_prev_5, prev_5, out_5);
            prev_1 = out_1;
            prev_3 = out_3;
            prev_5 = out_5;

            if (n >= 0) {
                dstp[@intCast(n)] = out_1 + out_3 + out_5;
            }
        }
    }
}

pub inline fn process(srcp: [*]const f32, dstp: [*]f32, stride: usize, width: usize, height: usize, d: *ssimulacra2.Ssimulacra2Data) void {
    if (d.tmp_blur.len == 1) {
        d.tmp_blur = allocator.alignedAlloc(f32, 64, stride * height) catch unreachable;
    }

    const tmpp = d.tmp_blur.ptr;
    h_pass(srcp, tmpp, stride, d, width, height);
    v_pass(tmpp, dstp, stride, d, width, height);
}

pub inline fn Inv3x3Matrix(matrix: [*]f64) void {
    var temp: [9]f64 = undefined;
    temp[0] = @mulAdd(f64, matrix[4], matrix[8], -(matrix[5] * matrix[7]));
    temp[1] = @mulAdd(f64, matrix[2], matrix[7], -(matrix[1] * matrix[8]));
    temp[2] = @mulAdd(f64, matrix[1], matrix[5], -(matrix[2] * matrix[4]));
    temp[3] = @mulAdd(f64, matrix[5], matrix[6], -(matrix[3] * matrix[8]));
    temp[4] = @mulAdd(f64, matrix[0], matrix[8], -(matrix[2] * matrix[6]));
    temp[5] = @mulAdd(f64, matrix[2], matrix[3], -(matrix[0] * matrix[5]));
    temp[6] = @mulAdd(f64, matrix[3], matrix[7], -(matrix[4] * matrix[6]));
    temp[7] = @mulAdd(f64, matrix[1], matrix[6], -(matrix[0] * matrix[7]));
    temp[8] = @mulAdd(f64, matrix[0], matrix[4], -(matrix[1] * matrix[3]));
    const det: f64 = @mulAdd(f64, matrix[0], temp[0], @mulAdd(f64, matrix[1], temp[3], (matrix[2] * temp[6])));

    const idet: f64 = 1.0 / det;
    var i: usize = 0;
    while (i < 9) : (i += 1) {
        matrix[i] = temp[i] * idet;
    }
}

pub inline fn MatMul(a: [*]f64, b: [*]f64, ha: usize, wa: usize, wb: usize, d: [*]f64) void {
    var temp: [wa]f64 = undefined;
    var x: usize = 0;
    while (x < wb) : (x += 1) {
        var z: usize = 0;
        while (z < wa) : (z += 1) {
            temp[z] = b[z * wb + x];
        }

        var y: usize = 0;
        while (y < ha) : (y += 1) {
            var e: f64 = 0.0;
            var j: usize = 0;
            while (j < wa) : (j += 1) {
                e += a[y * wa + j] * temp[j];
            }

            d[y * wb + x] = e;
        }
    }
}

pub inline fn gauss_init(sigma: f64, d: *ssimulacra2.Ssimulacra2Data) void {
    const kPi: f64 = 3.141592653589793238;
    const radius: f64 = @round(3.2795 * sigma + 0.2546);
    const pi_div_2r: f64 = kPi / (2.0 * radius);
    const omega = [3]f64{ pi_div_2r, 3.0 * pi_div_2r, 5.0 * pi_div_2r };
    const p_1: f64 = 1.0 / @tan(0.5 * omega[0]);
    const p_3: f64 = -1.0 / @tan(0.5 * omega[1]);
    const p_5: f64 = 1.0 / @tan(0.5 * omega[2]);
    const r_1: f64 = p_1 * p_1 / @sin(omega[0]);
    const r_3: f64 = -p_3 * p_3 / @sin(omega[1]);
    const r_5: f64 = p_5 * p_5 / @sin(omega[2]);
    const neg_half_sigma2: f64 = -0.5 * sigma * sigma;
    const recip_radius: f64 = 1.0 / radius;
    var rho: [3]f64 = undefined;

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        rho[i] = @exp(neg_half_sigma2 * omega[i] * omega[i]) * recip_radius;
    }

    const D_13: f64 = p_1 * r_3 - r_1 * p_3;
    const D_35: f64 = p_3 * r_5 - r_3 * p_5;
    const D_51: f64 = p_5 * r_1 - r_5 * p_1;
    const recip_d13: f64 = 1.0 / D_13;
    const zeta_15: f64 = D_35 * recip_d13;
    const zeta_35: f64 = D_51 * recip_d13;
    var A = [9]f64{ p_1, p_3, p_5, r_1, r_3, r_5, zeta_15, zeta_35, 1.0 };
    Inv3x3Matrix(&A);

    var gamma = [3]f64{ 1.0, radius * radius - sigma * sigma, zeta_15 * rho[0] + zeta_35 * rho[1] + rho[2] };
    var beta: [3]f64 = undefined;
    MatMul(&A, &gamma, 3, 3, 1, &beta);
    d.radius = @intFromFloat(radius);

    var n2: [3]f64 = undefined;
    var d1: [3]f64 = undefined;
    i = 0;
    while (i < 3) : (i += 1) {
        n2[i] = -beta[i] * @cos(omega[i] * (radius + 1.0));
        d1[i] = -2.0 * @cos(omega[i]);

        const d_2: f64 = d1[i] * d1[i];
        d.mul_prev[4 * i + 0] = @floatCast(-d1[i]);
        d.mul_prev[4 * i + 1] = @floatCast(d_2 - 1.0);
        d.mul_prev[4 * i + 2] = @floatCast(-d_2 * d1[i] + 2.0 * d1[i]);
        d.mul_prev[4 * i + 3] = @floatCast(d_2 * d_2 - 3.0 * d_2 + 1.0);
        d.mul_prev2[4 * i + 0] = -1.0;
        d.mul_prev2[4 * i + 1] = @floatCast(d1[i]);
        d.mul_prev2[4 * i + 2] = @floatCast(-d_2 + 1.0);
        d.mul_prev2[4 * i + 3] = @floatCast(d_2 * d1[i] - 2.0 * d1[i]);
        d.mul_in[4 * i + 0] = @floatCast(n2[i]);
        d.mul_in[4 * i + 1] = @floatCast(-d1[i] * n2[i]);
        d.mul_in[4 * i + 2] = @floatCast(d_2 * n2[i] - n2[i]);
        d.mul_in[4 * i + 3] = @floatCast(-d_2 * d1[i] * n2[i] + 2.0 * d1[i] * n2[i]);
    }
}
