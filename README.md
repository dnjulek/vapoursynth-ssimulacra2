# vapoursynth-chromanr
[![Linux](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/linux-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/linux-build.yml)
[![Windows](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/windows-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/windows-build.yml)

[SSIMULACRA2](https://github.com/cloudinary/ssimulacra2) for VapourSynth with Zig.

This implementation doesn't have the exact same result as the original, because a different gaussian blur algorithm is used,
a recursive gaussian blur is used there, and in this one a "true" gaussian blur with better performance is used.\
With this we get up to +70% speed.

If you want to use the original algorithm with VapourSynth, [see here](https://github.com/dnjulek/vapoursynth-julek-plugin/wiki/SSIMULACRA).

## Usage
```python
ssimulacra2.SSIMULACRA2(vnode reference, vnode distorted)
```

```python
ref = YUV420P8 clip
dist = YUV420P8 clip

# Only works with RGBS format.
ref = ref.resize.Bicubic(format=vs.RGBS, matrix_in=1)
dist = dist.resize.Bicubic(format=vs.RGBS, matrix_in=1)

# Must be converted from gamma to linear with fmtc because resize/zimg uses another formula.
ref = ref.fmtc.transfer(transs="srgb", transd="linear", bits=32)
dist = dist.fmtc.transfer(transs="srgb", transd="linear", bits=32)

ssim = core.ssimulacra2.SSIMULACRA2(ref, dist)
```

## Building
Zig ver >= 0.12.0-dev.1594

``zig build -Doptimize=ReleaseFast``
