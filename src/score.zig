const math = @import("std").math;

inline fn tothe4th(y: f64) f64 {
    var x = y * y;
    x *= x;
    return x;
}

pub inline fn ssim_map(
    s11: [*]f32,
    s22: [*]f32,
    s12: [*]f32,
    mu1: [*]f32,
    mu2: [*]f32,
    stride: usize,
    width: usize,
    height: usize,
    plane: usize,
    one_per_pixels: f64,
    plane_avg_ssim: [*]f64,
) void {
    var sum1 = [2]f64{ 0.0, 0.0 };
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var s11p = s11 + y * stride;
        var s22p = s22 + y * stride;
        var s12p = s12 + y * stride;
        var mu1p = mu1 + y * stride;
        var mu2p = mu2 + y * stride;

        var x: usize = 0;
        while (x < width) : (x += 1) {
            const m1: f32 = mu1p[x];
            const m2: f32 = mu2p[x];
            const m11 = m1 * m1;
            const m22 = m2 * m2;
            const m12 = m1 * m2;
            const m_diff = m1 - m2;
            const num_m: f64 = @mulAdd(f32, m_diff, -m_diff, 1.0);
            const num_s: f64 = @mulAdd(f32, (s12p[x] - m12), 2.0, 0.0009);
            const denom_s: f64 = (s11p[x] - m11) + (s22p[x] - m22) + 0.0009;
            const d1: f64 = @max(1.0 - ((num_m * num_s) / denom_s), 0.0);

            sum1[0] += d1;
            sum1[1] += tothe4th(d1);
        }
    }

    plane_avg_ssim[plane * 2] = one_per_pixels * sum1[0];
    plane_avg_ssim[plane * 2 + 1] = @sqrt(@sqrt(one_per_pixels * sum1[1]));
}

pub inline fn edge_map(
    im1: [*]f32,
    im2: [*]f32,
    mu1: [*]f32,
    mu2: [*]f32,
    stride: usize,
    width: usize,
    height: usize,
    plane: usize,
    one_per_pixels: f64,
    plane_avg_edge: [*]f64,
) void {
    var sum2 = [4]f64{ 0.0, 0.0, 0.0, 0.0 };
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var im1p = im1 + y * stride;
        var im2p = im2 + y * stride;
        var mu1p = mu1 + y * stride;
        var mu2p = mu2 + y * stride;

        var x: usize = 0;
        while (x < width) : (x += 1) {
            const d1: f64 = (1.0 + @as(f64, @abs(im2p[x] - mu2p[x]))) /
                (1.0 + @as(f64, @abs(im1p[x] - mu1p[x]))) - 1.0;
            const artifact: f64 = @max(d1, 0.0);
            sum2[0] += artifact;
            sum2[1] += tothe4th(artifact);
            const detail_lost: f64 = @max(-d1, 0.0);
            sum2[2] += detail_lost;
            sum2[3] += tothe4th(detail_lost);
        }
    }

    plane_avg_edge[plane * 4] = one_per_pixels * sum2[0];
    plane_avg_edge[plane * 4 + 1] = @sqrt(@sqrt(one_per_pixels * sum2[1]));
    plane_avg_edge[plane * 4 + 2] = one_per_pixels * sum2[2];
    plane_avg_edge[plane * 4 + 3] = @sqrt(@sqrt(one_per_pixels * sum2[3]));
}

pub inline fn score(plane_avg_ssim: [6][6]f64, plane_avg_edge: [6][12]f64) f64 {
    const weight = [108]f64{
        0.0,
        0.0007376606707406586,
        0.0,
        0.0,
        0.0007793481682867309,
        0.0,
        0.0,
        0.0004371155730107379,
        0.0,
        1.1041726426657346,
        0.00066284834129271,
        0.00015231632783718752,
        0.0,
        0.0016406437456599754,
        0.0,
        1.8422455520539298,
        11.441172603757666,
        0.0,
        0.0007989109436015163,
        0.000176816438078653,
        0.0,
        1.8787594979546387,
        10.94906990605142,
        0.0,
        0.0007289346991508072,
        0.9677937080626833,
        0.0,
        0.00014003424285435884,
        0.9981766977854967,
        0.00031949755934435053,
        0.0004550992113792063,
        0.0,
        0.0,
        0.0013648766163243398,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        7.466890328078848,
        0.0,
        17.445833984131262,
        0.0006235601634041466,
        0.0,
        0.0,
        6.683678146179332,
        0.00037724407979611296,
        1.027889937768264,
        225.20515300849274,
        0.0,
        0.0,
        19.213238186143016,
        0.0011401524586618361,
        0.001237755635509985,
        176.39317598450694,
        0.0,
        0.0,
        24.43300999870476,
        0.28520802612117757,
        0.0004485436923833408,
        0.0,
        0.0,
        0.0,
        34.77906344483772,
        44.835625328877896,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0008680556573291698,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0005313191874358747,
        0.0,
        0.00016533814161379112,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0004179171803251336,
        0.0017290828234722833,
        0.0,
        0.0020827005846636437,
        0.0,
        0.0,
        8.826982764996862,
        23.19243343998926,
        0.0,
        95.1080498811086,
        0.9863978034400682,
        0.9834382792465353,
        0.0012286405048278493,
        171.2667255897307,
        0.9807858872435379,
        0.0,
        0.0,
        0.0,
        0.0005130064588990679,
        0.0,
        0.00010854057858411537,
    };

    var ssim: f64 = 0.0;

    var i: usize = 0;
    var plane: usize = 0;

    while (plane < 3) : (plane += 1) {
        var s: usize = 0;
        while (s < 6) : (s += 1) {
            var n: usize = 0;
            while (n < 2) : (n += 1) {
                ssim = @mulAdd(f64, weight[i], @abs(plane_avg_ssim[s][plane * 2 + n]), ssim);
                i += 1;
                ssim = @mulAdd(f64, weight[i], @abs(plane_avg_edge[s][plane * 4 + n]), ssim);
                i += 1;
                ssim = @mulAdd(f64, weight[i], @abs(plane_avg_edge[s][plane * 4 + n + 2]), ssim);
                i += 1;
            }
        }
    }

    ssim *= 0.9562382616834844;
    ssim = (6.248496625763138e-5 * ssim * ssim) * ssim +
        2.326765642916932 * ssim -
        0.020884521182843837 * ssim * ssim;

    if (ssim > 0.0) {
        ssim = math.pow(f64, ssim, 0.6276336467831387) * -10.0 + 100.0;
    } else {
        ssim = 100.0;
    }

    return ssim;
}
