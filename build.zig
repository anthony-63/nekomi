const std = @import("std");

pub fn build(b: *std.Build) void {
    const target_os =
        if (b.option(bool, "WINDOWS", "Compile for windows") == null)
            std.Build.StandardTargetOptionsArgs{ .default_target = .{ .os_tag = .linux } }
        else
            std.Build.StandardTargetOptionsArgs{ .default_target = .{ .os_tag = .windows } };

    const target = b.standardTargetOptions(target_os);
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const dvui_dep = b.dependency("dvui", .{ .target = target, .optimize = optimize, .backend = .sdl3 });

    const shared = b.addModule("nekomi", .{
        .root_source_file = b.path("src/shared/root.zig"),
        .target = target,
    });

    var client_mod = b.createModule(.{
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "nekomi", .module = shared },
        },
    });
    client_mod.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    const client_exe = b.addExecutable(.{
        .name = "nekomiclient",
        .root_module = client_mod,
    });

    var server_mod = b.createModule(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "nekomi", .module = shared },
        },
    });
    server_mod.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    const server_exe = b.addExecutable(.{
        .name = "nekomiserver",
        .root_module = server_mod,
    });

    b.installArtifact(client_exe);
    b.installArtifact(server_exe);

    const crun_step = b.step("runc", "Run the client");

    const crun_cmd = b.addRunArtifact(client_exe);
    crun_step.dependOn(&crun_cmd.step);

    crun_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        crun_cmd.addArgs(args);
    }

    const srun_step = b.step("runs", "Run the server");

    const srun_cmd = b.addRunArtifact(server_exe);
    srun_step.dependOn(&srun_cmd.step);

    srun_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        srun_cmd.addArgs(args);
    }
}
