# MAVSDK Zig Build Integration

Zig build system integration for [MAVSDK](https://mavsdk.mavlink.io/) - the official SDK for MAVLink-compatible systems.

## Quick Start

1. Add to your project:
```bash
zig fetch --save git+https://github.com/neelsani/mavsdk
```
2. Add to you build.zig

```zig
const mavsdk_dep = b.dependency("mavsdk", .{
    .target = target,
    .optimize = optimize,
});
const lib = mavsdk_dep.artifact("mavsdk");

//then link it to your exe

exe.linkLibrary(lib);
```