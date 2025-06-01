const std = @import("std");
const Build = std.Build;
pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});

    const plugins = b.option(bool, "plugins", "build plugins") orelse true;
    const shared = b.option(bool, "shared", "build as a shared library") orelse false;
    // Create the mavsdk library
    const mavsdk_core = b.addLibrary(.{
        .name = "mavsdk",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });

    const MAVLINK_DIALECT = b.option([]const u8, "mavlink_dialect", "mavlink_dialect") orelse "common";
    const build_examples = b.option(bool, "examples", "build examples") orelse false;
    // Configure version.h
    const version_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("src/mavsdk/core/version.h.in") },
        .include_path = "version.h",
    }, .{
        .VERSION_STR = "1.0.0", // Replace with your actual version
    });
    mavsdk_core.addConfigHeader(version_h);
    // Configure mavlink_include.h
    const mavlink_include_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("src/mavsdk/core/include/mavsdk/mavlink_include.h.in") },
        .include_path = "mavlink_include.h",
    }, .{
        .MAVLINK_DIALECT = MAVLINK_DIALECT, // or your specific MAVLink dialect
    });
    mavsdk_core.addConfigHeader(mavlink_include_h);
    mavsdk_core.installHeader(mavlink_include_h.getOutput(), "mavsdk/mavlink_include.h");
    // Add source files
    const sources = [_][]const u8{
        "autopilot.cpp",
        "base64.cpp",
        "call_every_handler.cpp",
        "connection.cpp",
        "connection_result.cpp",
        "crc32.cpp",
        "system.cpp",
        "system_impl.cpp",
        "file_cache.cpp",
        "flight_mode.cpp",
        "fs_utils.cpp",
        "hostname_to_ip.cpp",
        "inflate_lzma.cpp",
        "math_utils.cpp",
        "mavsdk.cpp",
        "mavsdk_impl.cpp",
        "mavlink_channels.cpp",
        "mavlink_command_receiver.cpp",
        "mavlink_command_sender.cpp",
        "mavlink_component_metadata.cpp",
        "mavlink_ftp_client.cpp",
        "mavlink_ftp_server.cpp",
        "mavlink_mission_transfer_client.cpp",
        "mavlink_mission_transfer_server.cpp",
        "mavlink_parameter_cache.cpp",
        "mavlink_parameter_client.cpp",
        "mavlink_parameter_server.cpp",
        "mavlink_parameter_subscription.cpp",
        "mavlink_parameter_helper.cpp",
        "mavlink_receiver.cpp",
        "mavlink_request_message.cpp",
        "mavlink_request_message_handler.cpp",
        "mavlink_statustext_handler.cpp",
        "mavlink_message_handler.cpp",
        "param_value.cpp",
        "ping.cpp",
        "plugin_impl_base.cpp",
        "serial_connection.cpp",
        "server_component.cpp",
        "server_component_impl.cpp",
        "server_plugin_impl_base.cpp",
        "socket_holder.cpp",
        "tcp_client_connection.cpp",
        "tcp_server_connection.cpp",
        "timeout_handler.cpp",
        "udp_connection.cpp",
        "vehicle.cpp",
        "log.cpp",
        "cli_arg.cpp",
        "geometry.cpp",
        "mavsdk_time.cpp",
        "string_utils.cpp",
        "timesync.cpp",
    };

    mavsdk_core.addCSourceFiles(.{
        .files = &sources,
        .language = .cpp,
        .flags = &[_][]const u8{
            "-std=c++17",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-w",
        },
        .root = upstream.path("src/mavsdk/core"),
    });

    // Conditional CURL sources
    const build_without_curl = b.option(bool, "without-curl", "Build without CURL support") orelse false;

    if (!build_without_curl) {
        const curl_sources = [_][]const u8{
            "curl_wrapper.cpp",
            "http_loader.cpp",
        };

        mavsdk_core.addCSourceFiles(.{
            .files = &curl_sources,
            .language = .cpp,

            .flags = &[_][]const u8{
                "-std=c++17",
                "-Wall",
                "-Wextra",
                "-Werror",
            },
            .root = upstream.path("src/mavsdk/core"),
        });

        if (b.systemIntegrationOption("curl", .{})) {
            mavsdk_core.linkSystemLibrary("curl");
        } else {
            if (b.lazyDependency("curl", .{
                .target = target,
                .optimize = optimize,
                .pie = true,
                .@"use-openssl" = true,
                .libssh2 = false,
                .libpsl = false,
                .brotli = false,
                .zlib = false,
                .zstd = false,
                .@"http-only" = false,
                .nghttp2 = false,
                .libidn2 = false,
                .@"disable-ldap" = true, //System dep remove later ig
            })) |curl_dep| {
                const libCurl = curl_dep.artifact("libcurl");

                mavsdk_core.linkLibrary(libCurl);
            }
        }
    } else {
        mavsdk_core.root_module.addCMacro("BUILD_WITHOUT_CURL", "1");
    }

    // Include directories
    mavsdk_core.addIncludePath(upstream.path("src/mavsdk/core/include/mavsdk"));
    mavsdk_core.addIncludePath(upstream.path("src/mavsdk/core/")); // Current source directory

    // You'll need to set the MAVLink include path based on your setup
    // mavsdk.addIncludePath(.{ .path = "path/to/mavlink/include" });

    const mavlink_dep = b.dependency("mavlink_c", .{
        .target = target,
        .optimize = optimize,
        .dialect = MAVLINK_DIALECT, // or your preferred dialect
    });
    const mavlink_lib = mavlink_dep.artifact("mavlink");
    mavsdk_core.linkLibrary(mavlink_lib);
    mavsdk_core.installLibraryHeaders(mavlink_lib);

    const json_dep = b.dependency("jsoncpp", .{
        .target = target,
        .optimize = optimize,
    });
    const json_lib = json_dep.artifact("jsoncpp");
    mavsdk_core.linkLibrary(json_lib);
    // Link required libraries
    //mavsdk_core.linkSystemLibrary("lzma"); //need to zigify this soon

    const liblzma_dep = b.dependency("liblzma", .{
        .target = target,
        .optimize = optimize,
    });
    const liblzma_lib = liblzma_dep.artifact("liblzma");
    mavsdk_core.linkLibrary(liblzma_lib);

    // Platform-specific linking
    switch (target.result.os.tag) {
        .windows => {
            mavsdk_core.linkSystemLibrary("ws2_32");
            mavsdk_core.root_module.addCMacro("WINDOWS", "");
            if (optimize == .Debug) {
                // Add debug postfix equivalent if needed
            }
        },
        .macos, .ios => {
            mavsdk_core.linkFramework("Foundation");
            mavsdk_core.linkFramework("Security");
            mavsdk_core.root_module.addCMacro("APPLE", "");
        },
        .linux => {
            if (target.result.cpu.arch.isArm()) {
                mavsdk_core.linkSystemLibrary("atomic");
            }
            mavsdk_core.root_module.addCMacro("LINUX", "");
        },
        else => {},
    }

    // Android-specific
    if (target.result.abi.isAndroid()) {
        mavsdk_core.linkSystemLibrary("log");
    }

    // Threading support
    mavsdk_core.linkLibCpp();

    if (plugins) {
        addAllPlugins(b, upstream, mavsdk_core, &.{});
    }
    addPlugin(b, upstream, mavsdk_core, "mavlink_passthrough"); //not apart of plugins list

    const tinyxml_del = b.dependency("tinyxml2", .{
        .target = target,
        .optimize = optimize,
    });
    mavsdk_core.linkLibrary(tinyxml_del.artifact("tinyxml2"));

    const libevents_dep = b.dependency("libevents", .{
        .target = target,
        .optimize = optimize,
    });
    mavsdk_core.linkLibrary(libevents_dep.artifact("libevents"));

    mavsdk_core.installHeadersDirectory(upstream.path("src/mavsdk/core/include/mavsdk"), "mavsdk", .{});

    b.installArtifact(mavsdk_core);
    if (build_examples) {
        buildExamples(
            b,
            upstream,
            mavsdk_core,
            &.{},
            target,
            optimize,
        );
    }
}

// Build configuration options
pub const BuildOptions = struct {
    without_curl: bool = false,
    static_server: bool = false,
    version_string: []const u8 = "1.0.0",
    soversion_string: []const u8 = "1",
};

fn addPlugin(b: *std.Build, upstream: *std.Build.Dependency, lib: *std.Build.Step.Compile, name: []const u8) void {
    const path = upstream.path(b.fmt("src/mavsdk/plugins/{s}", .{name}));
    const abs_path = path.getPath(b);

    // Skip if directory doesn’t exist
    var dir = std.fs.cwd().openDir(abs_path, .{ .iterate = true }) catch {
        std.log.warn("Plugin directory '{s}' not found, skipping.", .{abs_path});
        return;
    };
    defer dir.close();

    var cpp_files = std.ArrayList([]const u8).init(b.allocator);
    defer cpp_files.deinit();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        // Skip non-files and non-.cpp files early
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".cpp")) {
            continue;
        }
        // Skip test files
        if (!std.mem.containsAtLeast(u8, entry.name, 1, "test")) {
            cpp_files.append(entry.name) catch continue;
        }
    }

    // Add filtered files to compilation
    lib.addCSourceFiles(.{
        .files = cpp_files.items,
        .root = path,
        .language = .cpp,
        .flags = &[_][]const u8{
            "-std=c++17",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-w",
        },
    });

    // Add include paths
    lib.addIncludePath(path.path(b, "include/"));
    lib.installHeadersDirectory(path.path(b, "include/"), "mavsdk/", .{});
}
pub fn addAllPlugins(b: *std.Build, upstream: *std.Build.Dependency, lib: *std.Build.Step.Compile, disable: []const []const u8) void {
    // Open the directory

    var file = std.fs.cwd().openFile(upstream.path("src/plugins.txt").getPath(b), .{}) catch {
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(b.allocator, std.math.maxInt(usize)) catch return;
    var lines = std.mem.splitSequence(u8, content, "\n");

    while (lines.next()) |entry| {
        if (entry.len > 1) {
            const should_disable = for (disable) |d| {
                if (std.mem.eql(u8, d, entry)) break true;
            } else false;

            if (!should_disable) {
                addPlugin(b, upstream, lib, entry);
            }
        }
    }
}

pub fn buildExamples(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    lib: *std.Build.Step.Compile,
    disable: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const path = upstream.path("examples");
    const abs_path = path.getPath(b);

    var dir = std.fs.cwd().openDir(abs_path, .{ .iterate = true }) catch |err| {
        std.log.err("Failed to open directory '{s}': {}", .{ abs_path, err });
        return;
    };
    defer dir.close();

    // Iterate through all files in the directory
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .directory) {
            const should_disable = for (disable) |d| {
                if (std.mem.eql(u8, d, entry.name)) break true;
            } else false;

            if (!should_disable) {
                buildExample(
                    b,
                    upstream,
                    lib,
                    entry.name,
                    target,
                    optimize,
                );
            }
        }
    }
}

fn buildExample(
    b: *std.Build,
    upstream: *std.Build.Dependency,
    lib: *std.Build.Step.Compile,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const path = upstream.path(b.fmt("examples/{s}", .{name}));
    const abs_path = path.getPath(b);
    const example = b.addExecutable(.{
        .target = target,
        .optimize = optimize,
        .name = name,
    });
    example.linkLibrary(lib);
    example.linkLibCpp();
    b.installArtifact(example);
    const allocator = b.allocator;

    // Open the directory
    var dir = std.fs.cwd().openDir(abs_path, .{ .iterate = true }) catch |err| {
        std.log.err("Failed to open directory '{s}': {}", .{ abs_path, err });
        return;
    };
    defer dir.close();

    var cpp_files = std.ArrayList([]const u8).init(allocator);
    defer cpp_files.deinit();

    // Iterate through all files in the directory
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            const is_cpp = std.mem.eql(u8, ext, ".cpp");
            const is_test = std.mem.containsAtLeast(u8, entry.name, 1, "test");

            if (is_cpp and !is_test) {
                cpp_files.append(entry.name) catch continue;
            }
        }
    }
    example.addIncludePath(lib.getEmittedIncludeTree().path(b, "mavsdk"));
    // Add all found C++ files to the compilation
    example.addCSourceFiles(.{
        .files = cpp_files.items,
        .root = path,
        .language = .cpp,
        .flags = &[_][]const u8{
            "-std=c++17",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-w",
        },
    });
}
