# A Simple Zig GDExtension

## Introduction

The scope of this tutorial is to recreate the [GDExtension C++ example](https://docs.godotengine.org/en/4.2/tutorials/scripting/gdextension/gdextension_cpp_example.html)
with two main differences:

1. We'll be writing it in [Zig](https://ziglang.org/) instead of C++.
2. No language bindings will be used, only the built-in GDExtension interface.

The goal here is to familiarize ourselves with the GDExtension interface in
order to know what to target when writing code generation for real language
bindings.

## References

A simpler example using C is available [here](https://github.com/gilzoide/hello-gdextension/blob/main/1.hello-c/README.md)
and is the greatest reference for this tutorial.

Reading the inline documentation for [gdextension_interface.h](https://github.com/godotengine/godot/blob/4.2-stable/core/extension/gdextension_interface.h),
as well as the [godot-hpp source code](https://github.com/godotengine/godot-cpp/tree/godot-4.2-stable)
is recommended as a more in-depth reference.

## Getting started

A GDExtension is a dynamic library (.dll on Windows, .so on Linux) loaded by
Godot at runtime (including in the editor). We can use `zig init` to scaffold
a project containing a static library (`src/root.zig`) and an executable
(`src/main.zig`). As we won't be needing the executable, we can remove its file
and associated configuration in `build.zig`. We should also substitute
`addSharedLibrary` for `addStaticLibrary` in order to build a dynamic lib. The
arguments should remain unchanged. After this call, we need to add the `src`
folder to the list of include paths, as we'll be including a C header file
later on. This can be accomplished by calling the `addIncludePath` method on the
`lib` object we just got.

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    // Changed from addStaticLibrary
    const lib = b.addSharedLibrary(.{
        .name = "zig-gdextension",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    // Enable Zig to find headers in the src folder
    lib.addIncludePath(.{ .path = "src" });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
```

Let's now create a Godot project to test our extension. Make a folder alongside
your `build.zig` and `src` folder; I'll call mine `project`, but you can give
it any name, like `demo`.

Create a scene with a single `Node` as root and save it as `main.tscn`.

Lastly before we start writing code, we need a header file containing the type
definitions for the GDExtension interface. The Godot executable can output this
file when run with the `--dump-gdextension-interface` argument. Alternatively,
you can download them [here](https://github.com/godotengine/godot-cpp/tree/godot-4.2-stable/gdextension).

When you've obtained the file, copy it to the `src` folder alongside `root.zig`.

