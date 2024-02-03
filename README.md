# vapoursynth-chromanr
[![Linux](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/linux-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/linux-build.yml)
[![Windows](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/windows-build.yml/badge.svg)](https://github.com/dnjulek/vapoursynth-ssimulacra2/actions/workflows/windows-build.yml)

[SSIMULACRA2](https://github.com/cloudinary/ssimulacra2) for VapourSynth with Zig.

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
[Download](https://ziglang.org/download/) the latest zig-dev and run ``zig build -Doptimize=ReleaseFast``

Or run the script that downloads it for you:
- Windows: [build.bat](/build.bat)
- Linux: [build.sh](/build.sh)
