pub inline fn process(src: [3][*]f32, dst: [3][*]f32, src_stride: usize, in_w: usize, in_h: usize) void {
    const fscale: f32 = 2.0;
    const uscale: usize = 2;
    const out_w = @divTrunc((in_w + uscale - 1), uscale);
    const out_h = @divTrunc((in_h + uscale - 1), uscale);
    const dst_stride = @divTrunc((src_stride + uscale - 1), uscale);
    const normalize: f32 = 1.0 / (fscale * fscale);

    var plane: usize = 0;
    while (plane < 3) : (plane += 1) {
        const srcp = src[plane];
        var dstp = dst[plane];
        var oy: usize = 0;
        while (oy < out_h) : (oy += 1) {
            var ox: usize = 0;
            while (ox < out_w) : (ox += 1) {
                var sum: f32 = 0.0;
                var iy: usize = 0;
                while (iy < uscale) : (iy += 1) {
                    var ix: usize = 0;
                    while (ix < uscale) : (ix += 1) {
                        const x: usize = @min((ox * uscale + ix), (in_w - 1));
                        const y: usize = @min((oy * uscale + iy), (in_h - 1));
                        sum += srcp[y * src_stride + x];
                    }
                }
                dstp[ox] = sum * normalize;
            }
            dstp += dst_stride;
        }
    }
}
