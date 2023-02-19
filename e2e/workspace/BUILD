"""Provides a simple way to test your rules as an external workspace.
Add a basic smoke-test target below.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@com_github_gonzojive_rules_sass//sass:defs.bzl", "sass_binary")

# Replace with a usage of your rule/macro
filegroup(name = "empty")

build_test(
    name = "smoke_test",
    targets = [
        # targets you add above
        ":hello_world_no_sourcemap",
        ":hello_world_sourcemap_embed_sources",
    ],
)

sass_binary(
    name = "hello_world_sourcemap_embed_sources",
    src = "main.scss",
    output_name = "main-sourcemap-embed-sources.css",
    sourcemap_embed_sources = True,
    deps = [
    ],
)

sass_binary(
    name = "hello_world_no_sourcemap",
    src = "main.scss",
    output_name = "main-no-sourcemap.css",
    sourcemap = False,
    deps = [
    ],
)
