// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig -lc
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // Create a library target
    const target = b.standardTargetOptions(.{});

    const lib = b.addSharedLibrary(.{ .name = "reaper_zig", .root_source_file = b.path("src/hello_world.zig"), .target = target, .optimize = .Debug });

    const root = b.path("./src/");
    lib.addIncludePath(root);

    // -shared reaper_barebone.cpp -o reaper_barebone.so
    const sourcefileOpts = std.Build.Module.AddCSourceFilesOptions{ .files = &.{ "./src/fakeCsurf.cpp", "src/fakeCsurfWrapper.cpp" }, .flags = &.{ "-fPIC", "-O2", "-std=c++14", "-IWDL/WDL" } };

    lib.addCSourceFiles(sourcefileOpts);
    lib.linkLibC();
    lib.linkLibCpp();

    // Ensure the library is built when the default build target is run
    b.installArtifact(lib);

    // Default step for building
    const step = b.step("default", "Build reaper_zig.so");
    step.dependOn(&lib.step);
}