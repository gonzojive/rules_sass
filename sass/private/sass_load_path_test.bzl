"""Tests sass_load_path.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":sass_load_path.bzl", "SassLoadPathInfo", "create_load_path_directory_specs", "path_and_parent_paths")

def _path_and_parent_paths_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        ["a", "a/b", "a/b/c"],
        path_and_parent_paths(
            "a/b/c",
        ),
    )
    return unittest.end(env)

def _create_load_path_directory_specs_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        [
            struct(
                load_path = "output_place",
                mkdirs = ["@angular"],
                symlinks = [
                    struct(
                        link_path = "output_place/@angular/material",
                        target_path = "../../foo/bar/node_modules/@angular/material",
                    ),
                ],
            ),
        ],
        create_load_path_directory_specs(
            "output_place",
            [
                SassLoadPathInfo(
                    directory = struct(
                        path = "foo/bar/node_modules/@angular/material",
                    ),
                    import_path = "@angular/material",
                ),
            ],
        ),
    )

    asserts.equals(
        env,
        [
            struct(
                load_path = "output_place",
                mkdirs = [
                    "@angular",
                    "some",
                    "some/extra",
                ],
                symlinks = [
                    struct(
                        link_path = "output_place/@angular/material",
                        target_path = "../../foo/bar/node_modules/@angular/material",
                    ),
                    struct(
                        link_path = "output_place/some/extra/styles",
                        target_path = "../../../foo/bar/node_modules/some/styles",
                    ),
                ],
            ),
        ],
        create_load_path_directory_specs(
            "output_place",
            [
                SassLoadPathInfo(
                    directory = struct(
                        path = "foo/bar/node_modules/@angular/material",
                    ),
                    import_path = "@angular/material",
                ),
                SassLoadPathInfo(
                    directory = struct(
                        path = "foo/bar/node_modules/some/styles",
                    ),
                    import_path = "some/extra/styles",
                ),
            ],
        ),
    )

    asserts.equals(
        env,
        [
            struct(
                load_path = "output_place/load_path_0",
                mkdirs = [
                ],
                symlinks = [
                    struct(
                        link_path = "output_place/load_path_0/@angular",
                        target_path = "../../foo/bar/node_modules/@angular",
                    ),
                ],
            ),
            struct(
                load_path = "output_place/load_path_1",
                mkdirs = [
                    "@angular",
                ],
                symlinks = [
                    struct(
                        link_path = "output_place/load_path_1/@angular/thing",
                        target_path = "../../../foo/bar/node_modules/@angular/thing",
                    ),
                ],
            ),
        ],
        create_load_path_directory_specs(
            "output_place",
            [
                SassLoadPathInfo(
                    directory = struct(
                        path = "foo/bar/node_modules/@angular",
                    ),
                    import_path = "@angular",
                ),
                SassLoadPathInfo(
                    directory = struct(
                        path = "foo/bar/node_modules/@angular/thing",
                    ),
                    import_path = "@angular/thing",
                ),
            ],
        ),
    )
    return unittest.end(env)

path_and_parent_paths_test = unittest.make(_path_and_parent_paths_test_impl)
create_load_path_directory_specs_test = unittest.make(_create_load_path_directory_specs_test_impl)

# No need for a test_create_load_path_directory_specs() setup function.

def create_load_path_directory_test_suite(name):
    # unittest.suite() takes care of instantiating the testing rules and creating
    # a test_suite.
    unittest.suite(
        name,
        path_and_parent_paths_test,
        create_load_path_directory_specs_test,
    )
