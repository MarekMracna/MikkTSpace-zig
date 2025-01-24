const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("root", .{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "mikk-tspace",
        .root_module = lib_mod,
    });

    lib.addIncludePath(b.path("."));
    lib.linkLibC();
    lib.addCSourceFile(.{
        .file = b.path("mikktspace.c"),
        .flags = &.{},
    });

    b.installArtifact(lib);
}
