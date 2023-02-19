# Declare the local Bazel workspace.
workspace(
    # If your ruleset is "official"
    # (i.e. is in the bazelbuild GitHub org)
    # then this should just be named "rules_sass"
    # see https://docs.bazel.build/versions/main/skylark/deploying.html#workspace
    name = "com_github_gonzojive_rules_sass",
)

load(":internal_deps.bzl", "rules_sass_internal_deps")

# Fetch deps needed only locally for development
rules_sass_internal_deps()

load("//sass:repositories.bzl", "rules_sass_dependencies", "sass_register_toolchains")

# Fetch dependencies which users need as well
rules_sass_dependencies()

sass_register_toolchains(
    name = "sass1_58_8",
    sass_version = "1.58.8",
)

# For running our own unit tests
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

############################################
# Gazelle, for generating bzl_library targets
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.19.3")

gazelle_dependencies()
