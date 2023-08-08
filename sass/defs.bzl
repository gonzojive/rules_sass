# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"Compile Sass files to CSS"

load("@bazel_skylib//lib:paths.bzl", "paths")

_ALLOWED_SRC_FILE_EXTENSIONS = [".sass", ".scss", ".css", ".svg", ".png", ".gif", ".cur", ".jpg", ".webp"]

# Documentation for switching which compiler is used
_COMPILER_ATTR_DOC = """Choose which Sass compiler binary to use.

By default, we use the JavaScript-transpiled version of the
dart-sass library, based on https://github.com/sass/dart-sass.
This is the canonical compiler under active development by the Sass team.
This compiler is convenient for frontend developers since it's released
as JavaScript and can run natively in NodeJS without being locally built.
While the compiler can be configured, there are no other implementations
explicitly supported at this time. In the future, there will be an option
to run Dart Sass natively in the Dart VM. This option depends on the Bazel
rules for Dart, which are currently not actively maintained (see
https://github.com/dart-lang/rules_dart).
"""

SassInfo = provider(
    doc = "Collects files from sass_library for use in downstream sass_binary",
    fields = {
        "transitive_sources": "Sass sources for this target and its dependencies",
    },
)

SassDirDepInfo = provider(
    doc = "Information about a generated directory of files to be passed to sass.",
    fields = {
        "dir": "Sass sources for this target and its dependencies",
    },
)

def _sass_load_path_dir_impl(ctx):
    """sass_load_path_dir creates a directory 

    It doesn't execute any actions.

    Args:
      ctx: The Bazel build context

    Returns:
      The sass_load_path_dir rule.
    """

    dir = ctx.file.src
    if not dir.is_directory:
        fail("src must be a directory, got {}".format(dir))

    if ctx.attr.import_path:
        output_dir = ctx.actions.declare_directory(ctx.label.name + ".output")
        output_dir_symlink = ctx.actions.declare_symlink(ctx.label.name + ".output_symlink")
        dir = output_dir

        # Make all the directories except for the final one, which is what will
        # be symliked.
        dirs_to_make = paths.dirname(ctx.attr.import_path)

        suffix = "/" + dirs_to_make if dirs_to_make else ""

        ctx.actions.run_shell(
            outputs = [output_dir],
            inputs = [],
            arguments = [output_dir.path + suffix],
            command = """mkdir -p "$1" && exit 1""",
            progress_message = "Making --load-path directory",
        )
        link_path = paths.join(output_dir.path, ctx.attr.import_path)
        target_file = ctx.file.src

        # print("want to link {} -> {} but don't know how".format(link_path, target_file.path))
        # print(
        #     "ln --symbolic {} {}".format(
        #         _relative_path(target_file.path, paths.dirname(link_path)),
        #         link_path,
        #     ),
        # )

        # fail("blah")

        # ctx.actions.run_shell(
        #     outputs = [output_dir],
        #     inputs = [],
        #     arguments = [output_dir.path + suffix],
        #     command = """ln --symbolic"$1" && exit 1""",
        #     progress_message = "Symlinking target directory into directory tree.",
        # )
        ctx.actions.symlink(
            output = paths.join(output_dir.path, paths.basename(ctx.attr.import_path)),
            target_file = ctx.file.src,
        )

        # ctx.actions.symlink(

        # )

    return [
        SassDirDepInfo(
            dir = dir,
        ),
        DefaultInfo(
            files = depset(direct = [dir]),
        ),
    ]

sass_load_path_dir = rule(
    implementation = _sass_load_path_dir_impl,
    attrs = {
        "src": attr.label(
            doc = """File or directory that should be use-able from another
            sass source.""",
            #allow_files = True,
            allow_single_file = True,
            mandatory = True,
        ),
        "import_path": attr.string(
            default = """If 'foo', and src='baz/x', use 'foo/x' can be used to
            import the library""",
            doc = "",
        ),
    },
    doc = """Defines a group of Sass include files.""",
)

def _collect_transitive_sources(srcs, deps):
    "Sass compilation requires all transitive .sass source files"
    return depset(
        srcs,
        transitive = [dep[SassInfo].transitive_sources for dep in deps],
        # Provide .sass sources from dependencies first
        order = "postorder",
    )

def _sass_library_impl(ctx):
    """sass_library collects all transitive sources for given srcs and deps.

    It doesn't execute any actions.

    Args:
      ctx: The Bazel build context

    Returns:
      The sass_library rule.
    """
    transitive_sources = _collect_transitive_sources(
        ctx.files.srcs,
        ctx.attr.deps,
    )
    return [
        SassInfo(transitive_sources = transitive_sources),
        DefaultInfo(
            files = transitive_sources,
        ),
    ]

def _run_sass(ctx, input, css_output, map_output = None):
    """run_sass performs an action to compile a single Sass file into CSS."""

    # The Sass CLI expects inputs like
    # sass <flags> <input_filename> <output_filename>
    args = ctx.actions.args()

    # By default, the CLI of Sass writes the output file even if compilation failures have been
    # reported. We don't want this behavior in the Bazel action, as writing the actual output
    # file could let the compilation action appear successful. Instead, if we do not write any
    # file on error, Bazel will never report the action as successful if an error occurred.
    # https://sass-lang.com/documentation/cli/dart-sass#error-css
    args.add("--no-error-css")

    # Flags (see https://github.com/sass/dart-sass/blob/master/lib/src/executable/options.dart)
    args.add_joined(["--style", ctx.attr.output_style], join_with = "=")

    if not ctx.attr.sourcemap:
        args.add("--no-source-map")
    elif ctx.attr.sourcemap_embed_sources:
        args.add("--embed-sources")

    # Sources for compilation may exist in the source tree, in bazel-bin, or bazel-genfiles.
    # for prefix in [".", ctx.var["BINDIR"], ctx.var["GENDIR"]]:
    #     args.add("--load-path=%s/" % prefix)
    #     for include_path in ctx.attr.include_paths:
    #         args.add("--load-path=%s/%s" % (prefix, include_path))

    # Last arguments are input and output paths
    # Note that the sourcemap is implicitly written to a path the same as the
    # css with the added .map extension.
    args.add_all([input.path, css_output.path])
    #args.use_param_file("@%s", use_always = True)
    #args.set_param_file_format("multiline")

    toolchain = ctx.toolchains["//sass:toolchain_type"]
    toolchain_info = toolchain.sassinfo

    ctx.actions.run(
        mnemonic = "SassCompiler",
        executable = toolchain_info.target_tool_path,
        inputs = _collect_transitive_sources([input], ctx.attr.deps),
        tools = toolchain_info.tool_files,
        arguments = [args],
        outputs = [css_output, map_output] if map_output else [css_output],
        use_default_shell_env = True,
        # execution_requirements = {"supports-workers": "1"},
    )

def _sass_binary_impl(ctx):
    # Make sure the output CSS is available in runfiles if used as a data dep.
    if ctx.attr.sourcemap:
        map_file = ctx.outputs.map_file
        outputs = [ctx.outputs.css_file, map_file]
    else:
        map_file = None
        outputs = [ctx.outputs.css_file]

    _run_sass(ctx, ctx.file.src, ctx.outputs.css_file, map_file)
    return DefaultInfo(runfiles = ctx.runfiles(files = outputs))

def _sass_binary_outputs(src, output_name, output_dir, sourcemap):
    """Get map of sass_binary outputs, including generated css and sourcemaps.

    Note that the arguments to this function are named after attributes on the rule.

    Args:
      src: The rule's `src` attribute
      output_name: The rule's `output_name` attribute
      output_dir: The rule's `output_dir` attribute
      sourcemap: The rule's `sourcemap` attribute

    Returns:
      Outputs for the sass_binary
    """

    output_name = output_name or _strip_extension(src.name) + ".css"
    css_file = "/".join([p for p in [output_dir, output_name] if p])

    outputs = {
        "css_file": css_file,
    }

    if sourcemap:
        outputs["map_file"] = "%s.map" % css_file

    return outputs

def _strip_extension(path):
    """Removes the final extension from a path."""
    components = path.split(".")
    components.pop()
    return ".".join(components)

sass_deps_attr = attr.label_list(
    doc = "sass_library targets to include in the compilation",
    providers = [SassInfo],
    allow_files = False,
)

_sass_library_attrs = {
    "srcs": attr.label_list(
        doc = "Sass source files",
        allow_files = _ALLOWED_SRC_FILE_EXTENSIONS,
        allow_empty = False,
        mandatory = True,
    ),
    "deps": sass_deps_attr,
}

sass_library = rule(
    implementation = _sass_library_impl,
    attrs = _sass_library_attrs,
    doc = """Defines a group of Sass include files.""",
)

_sass_binary_attrs = {
    "src": attr.label(
        doc = "Sass entrypoint file",
        mandatory = True,
        allow_single_file = _ALLOWED_SRC_FILE_EXTENSIONS,
    ),
    "sourcemap": attr.bool(
        default = True,
        doc = "Whether source maps should be emitted.",
    ),
    "sourcemap_embed_sources": attr.bool(
        default = False,
        doc = "Whether to embed source file contents in source maps.",
    ),
    "include_paths": attr.string_list(
        doc = "Additional directories to search when resolving imports",
    ),
    "output_dir": attr.string(
        doc = "Output directory, relative to this package.",
        default = "",
    ),
    "output_name": attr.string(
        doc = """Name of the output file, including the .css extension.

By default, this is based on the `src` attribute: if `styles.scss` is
the `src` then the output file is `styles.css.`.
You can override this to be any other name.
Note that some tooling may assume that the output name is derived from
the input name, so use this attribute with caution.""",
        default = "",
    ),
    "output_style": attr.string(
        doc = "How to style the compiled CSS",
        default = "compressed",
        values = [
            "expanded",
            "compressed",
        ],
    ),
    "deps": sass_deps_attr,
    # "_compiler": attr.label(
    #     doc = _COMPILER_ATTR_DOC,
    #     default = Label("//sass"),
    #     executable = True,
    #     allow_files = True,
    #     cfg = "exec",
    #     #providers = [SassToolchainInfo],
    # ),
}

sass_binary = rule(
    implementation = _sass_binary_impl,
    attrs = _sass_binary_attrs,
    outputs = _sass_binary_outputs,
    toolchains = ["//sass:toolchain_type"],
)

# def _multi_sass_binary_impl(ctx):
#     """multi_sass_binary accepts a list of sources and compile all in one pass.

#     Args:
#       ctx: The Bazel build context

#     Returns:
#       The multi_sass_binary rule.
#     """

#     inputs = ctx.files.srcs
#     outputs = []

#     # Every non-partial Sass file will produce one CSS output file and,
#     # optionally, one sourcemap file.
#     for f in inputs:
#         # Sass partial files (prefixed with an underscore) do not produce any
#         # outputs.
#         if f.basename.startswith("_"):
#             continue
#         name = _strip_extension(f.basename)
#         outputs.append(ctx.actions.declare_file(
#             name + ".css",
#             sibling = f,
#         ))
#         if ctx.attr.sourcemap:
#             outputs.append(ctx.actions.declare_file(
#                 name + ".css.map",
#                 sibling = f,
#             ))

#     # Use the package directory as the compilation root given to the Sass compiler
#     root_dir = (ctx.label.workspace_root + "/" if ctx.label.workspace_root else "") + ctx.label.package

#     # Declare arguments passed through to the Sass compiler.
#     # Start with flags and then expected program arguments.
#     args = ctx.actions.args()
#     args.add("--style", ctx.attr.output_style)
#     args.add("--load-path", root_dir)

#     if not ctx.attr.sourcemap:
#         args.add("--no-source-map")

#     args.add(root_dir + ":" + ctx.bin_dir.path + "/" + root_dir)
#     args.use_param_file("@%s", use_always = True)
#     args.set_param_file_format("multiline")

#     if inputs:
#         ctx.actions.run(
#             inputs = inputs,
#             outputs = outputs,
#             executable = ctx.executable.compiler,
#             arguments = [args],
#             mnemonic = "SassCompiler",
#             progress_message = "Compiling Sass",
#         )

#     return [DefaultInfo(files = depset(outputs))]

# multi_sass_binary = rule(
#     implementation = _multi_sass_binary_impl,
#     attrs = {
#         "srcs": attr.label_list(
#             doc = "A list of Sass files and associated assets to compile",
#             allow_files = _ALLOWED_SRC_FILE_EXTENSIONS,
#             allow_empty = True,
#             mandatory = True,
#         ),
#         "sourcemap": attr.bool(
#             doc = "Whether sourcemaps should be emitted",
#             default = True,
#         ),
#         "output_style": attr.string(
#             doc = "How to style the compiled CSS",
#             default = "compressed",
#             values = [
#                 "expanded",
#                 "compressed",
#             ],
#         ),
#         "compiler": attr.label(
#             doc = _COMPILER_ATTR_DOC,
#             default = Label("//sass"),
#             executable = True,
#             cfg = "exec",
#         ),
#     },
# )
