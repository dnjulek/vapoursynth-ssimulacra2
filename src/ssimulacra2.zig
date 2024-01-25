const std = @import("std");
const vs = @import("vapoursynth").vapoursynth4;
const vsh = @import("vapoursynth").vshelper;

const blur = @import("blur.zig");
const downscale = @import("downscale.zig");
const multiply = @import("multiply.zig");
const score = @import("score.zig");
const xyb = @import("xyb.zig");

const math = std.math;
const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;
const cf = vs.ColorFamily;
const ma = vs.MapAppendMode;
const vec_t: type = @Vector(16, f32);

const allocator = std.heap.c_allocator;

pub const Ssimulacra2Data = struct {
    node1: ?*vs.Node,
    node2: ?*vs.Node,
};

inline fn copy_data(dst: [3][*]f32, src: [3][*]const f32, stride: usize, width: usize, height: usize) void {
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var dstp = dst[i];
        var srcp = src[i];
        var y: usize = 0;
        while (y < height) : (y += 1) {
            @memcpy(dstp[0..width], srcp[0..width]);
            srcp += stride;
            dstp += stride;
        }
    }
}

inline fn process(src8a: [3][*]const u8, src8b: [3][*]const u8, stride8: usize, width: usize, height: usize) f64 {
    const stride: usize = stride8 >> (@sizeOf(f32) >> 1);

    const srcp1 = [3][*]const f32{
        @ptrCast(@alignCast(src8a[0])),
        @ptrCast(@alignCast(src8a[1])),
        @ptrCast(@alignCast(src8a[2])),
    };

    const srcp2 = [3][*]const f32{
        @ptrCast(@alignCast(src8b[0])),
        @ptrCast(@alignCast(src8b[1])),
        @ptrCast(@alignCast(src8b[2])),
    };

    const wh: usize = stride * height;
    const tmp_arr = allocator.alignedAlloc(f32, 32, wh * 18) catch unreachable;
    defer allocator.free(tmp_arr);
    const tempp = tmp_arr.ptr;
    const srcp1b = [3][*]f32{ tempp, tempp + wh, tempp + (wh * 2) };
    const srcp2b = [3][*]f32{ tempp + (wh * 3), tempp + (wh * 4), tempp + (wh * 5) };
    const tmpp1 = [3][*]f32{ tempp + (wh * 6), tempp + (wh * 7), tempp + (wh * 8) };
    const tmpp2 = [3][*]f32{ tempp + (wh * 9), tempp + (wh * 10), tempp + (wh * 11) };

    const tmpp3: [*]f32 = tempp + (wh * 12);
    const tmpps11: [*]f32 = tempp + (wh * 13);
    const tmpps22: [*]f32 = tempp + (wh * 14);
    const tmpps12: [*]f32 = tempp + (wh * 15);
    const tmppmu1: [*]f32 = tempp + (wh * 16);

    copy_data(srcp1b, srcp1, stride, width, height);
    copy_data(srcp2b, srcp2, stride, width, height);

    var plane_avg_ssim: [6][6]f64 = undefined;
    var plane_avg_edge: [6][12]f64 = undefined;
    var stride2 = stride;
    var width2 = width;
    var height2 = height;

    var scale: usize = 0;
    while (scale < 6) : (scale += 1) {
        if (scale > 0) {
            downscale.process(srcp1b, srcp1b, stride2, width2, height2);
            downscale.process(srcp2b, srcp2b, stride2, width2, height2);
            stride2 = @divTrunc((stride2 + 1), 2);
            width2 = @divTrunc((width2 + 1), 2);
            height2 = @divTrunc((height2 + 1), 2);
        }

        const one_per_pixels: f64 = 1.0 / @as(f64, @floatFromInt(width2 * height2));
        xyb.process(srcp1b, tmpp1, stride2, width2, height2);
        xyb.process(srcp2b, tmpp2, stride2, width2, height2);

        var plane: usize = 0;
        while (plane < 3) : (plane += 1) {
            multiply.process(tmpp1[plane], tmpp1[plane], tmpp3, stride2, width2, height2);
            blur.process(tmpp3, tmpps11, stride2, width2, height2);

            multiply.process(tmpp2[plane], tmpp2[plane], tmpp3, stride2, width2, height2);
            blur.process(tmpp3, tmpps22, stride2, width2, height2);

            multiply.process(tmpp1[plane], tmpp2[plane], tmpp3, stride2, width2, height2);
            blur.process(tmpp3, tmpps12, stride2, width2, height2);

            blur.process(tmpp1[plane], tmppmu1, stride2, width2, height2);
            blur.process(tmpp2[plane], tmpp3, stride2, width2, height2);

            score.ssim_map(
                tmpps11,
                tmpps22,
                tmpps12,
                tmppmu1,
                tmpp3,
                stride2,
                width2,
                height2,
                plane,
                one_per_pixels,
                &plane_avg_ssim[scale],
            );

            score.edge_map(
                tmpp1[plane],
                tmpp2[plane],
                tmppmu1,
                tmpp3,
                stride2,
                width2,
                height2,
                plane,
                one_per_pixels,
                &plane_avg_edge[scale],
            );
        }
    }

    return score.score(plane_avg_ssim, plane_avg_edge);
}

export fn ssimulacra2GetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    _ = frame_data;
    const d: *Ssimulacra2Data = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        vsapi.?.requestFrameFilter.?(n, d.node1, frame_ctx);
        vsapi.?.requestFrameFilter.?(n, d.node2, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src1 = vsapi.?.getFrameFilter.?(n, d.node1, frame_ctx);
        const src2 = vsapi.?.getFrameFilter.?(n, d.node2, frame_ctx);
        defer vsapi.?.freeFrame.?(src1);
        defer vsapi.?.freeFrame.?(src2);

        const width: usize = @intCast(vsapi.?.getFrameWidth.?(src1, 0));
        const height: usize = @intCast(vsapi.?.getFrameHeight.?(src1, 0));
        const stride: usize = @intCast(vsapi.?.getStride.?(src1, 0));
        const dst = vsapi.?.copyFrame.?(src2, core).?;

        const srcp1 = [3][*]const u8{
            vsapi.?.getReadPtr.?(src1, 0),
            vsapi.?.getReadPtr.?(src1, 1),
            vsapi.?.getReadPtr.?(src1, 2),
        };

        const srcp2 = [3][*]const u8{
            vsapi.?.getReadPtr.?(src2, 0),
            vsapi.?.getReadPtr.?(src2, 1),
            vsapi.?.getReadPtr.?(src2, 2),
        };

        const val = process(
            srcp1,
            srcp2,
            stride,
            width,
            height,
        );

        _ = vsapi.?.mapSetFloat.?(vsapi.?.getFramePropertiesRW.?(dst), "_SSIMULACRA2", val, ma.Replace);
        return dst;
    }
    return null;
}

export fn ssimulacra2Free(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *Ssimulacra2Data = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node1);
    vsapi.?.freeNode.?(d.node2);
    allocator.destroy(d);
}

export fn ssimulacra2Create(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: Ssimulacra2Data = undefined;
    var err: c_int = undefined;

    d.node1 = vsapi.?.mapGetNode.?(in, "reference", 0, &err).?;
    d.node2 = vsapi.?.mapGetNode.?(in, "distorted", 0, &err).?;
    const vi: *const vs.VideoInfo = vsapi.?.getVideoInfo.?(d.node1);

    if (!(vsh.isSameVideoInfo(vi, vsapi.?.getVideoInfo.?(d.node2)))) {
        vsapi.?.mapSetError.?(out, "SSIMULACRA2: both clips must have the same format and dimensions.");
        vsapi.?.freeNode.?(d.node1);
        vsapi.?.freeNode.?(d.node2);
        return;
    }

    if ((vi.format.colorFamily != cf.RGB) or (vi.format.sampleType != st.Float)) {
        vsapi.?.mapSetError.?(out, "SSIMULACRA2: only works with RGBS format.");
        vsapi.?.freeNode.?(d.node1);
        vsapi.?.freeNode.?(d.node2);
        return;
    }

    const data: *Ssimulacra2Data = allocator.create(Ssimulacra2Data) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node1,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.node2,
            .requestPattern = rp.StrictSpatial,
        },
    };

    vsapi.?.createVideoFilter.?(out, "ssimulacra2", vi, ssimulacra2GetFrame, ssimulacra2Free, fm.Parallel, &deps, deps.len, data, core);
}

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vspapi: *const vs.PLUGINAPI) void {
    _ = vspapi.configPlugin.?("com.julek.ssimulacra2", "ssimulacra2", "VapourSynth SSIMULACRA2", vs.makeVersion(3, 0), vs.VAPOURSYNTH_API_VERSION, 0, plugin);
    _ = vspapi.registerFunction.?("SSIMULACRA2", "reference:vnode;distorted:vnode;", "clip:vnode;", ssimulacra2Create, null, plugin);
}
