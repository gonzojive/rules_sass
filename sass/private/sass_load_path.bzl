"""The sass_load_path rule and related functionality.

See
https://docs.google.com/document/d/1XHRXFgztlYzOkW-zS5VW2owV9r-cwI8X0xQ3qlvLNRA/edit?resourcekey=0-MS8kbQpAfFko9pJOAMP9DQ#bookmark=id.5929w9chq0mm
for a related design doc.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//sass/private:pathutil.bzl", _relative_path = "relative_path")

SassLoadPathInfo = provider(
    doc = """An (import alias, directory label) pair for a sass dependency.

    SassLoadPathInfo is provided by the `sass_load_path` rule. The import alias
    can be used by other sass dependencies.
    """,
    fields = {
        "directory": "A File for the directory with sass files.",
        "import_path": """The import path sass files can use for the directory.

        If import_path is 'foo/bar', a --load-path must be provided to the
        sass compiler with the path to a directory that contains 'foo', and
        'foo/bar' must contain all of the files within the directory of the
        directory field of this provider.
        """,
    },
)

def _sass_load_path_impl(ctx):
    """sass_load_path specifies a single sass directory that should be importable.

    It doesn't execute any actions.

    Args:
      ctx: The Bazel build context

    Returns:
      A SassLoadPathInfo provider.
    """
    if not ctx.file.directory.is_directory:
        fail("directory attribute {} must be a directory".format(ctx.files.directory))
    load_path_info = SassLoadPathInfo(
        directory = ctx.attr.directory,
        import_path = ctx.attr.import_path,
    )
    return [load_path_info]

sass_load_path = rule(
    implementation = _sass_load_path_impl,
    attrs = {
        "directory": attr.label(
            doc = "A directory label that contains Sass files.",
            allow_single_file = True,
            mandatory = True,
        ),
        "import_path": attr.string(
            doc = "Import path that can be used in Sass files to import the directory.",
            mandatory = True,
        ),
    },
    doc = """Defines a group of Sass include files.""",
)

def _load_path_info_directory_path(load_path_info):
    return load_path_info.directory.path

def create_load_path_directory(
        ctx,
        dir_path,
        load_path_infos):
    """Runs a program that creates the

    Args:
        ctx: The bazel ctx of a rule.
        dir_path: (string) The output path of the directory to create and
          populate.
        load_path_infos: A sequence of SassLoadPathInfo structs that should
          be processed.

    Returns:
        A list of paths to pass to sass's --load-path flag.
    """
    specs = create_load_path_directory_specs(
        dir_path,
        load_path_infos,
    )

    all_commands = []

def create_load_path_directory_specs(
        dir_path,
        load_path_infos):  #        get_directory_path):
    """Runs a program that creates the

    Args:
        dir_path: (string) The output path of the directory to create and
          populate.
        load_path_infos: A sequence of SassLoadPathInfo structs that should
          be processed.

    Returns:
        A list of paths to pass to sass's --load-path flag.
    """
    get_directory_path = _load_path_info_directory_path

    create_specs = []

    def _new_create_spec():
        create_specs.append(struct(mkdirs = {}, load_path_infos = []))
        return create_specs[-1]

    def _should_add_load_path_info_to_spec(spec, info):
        if info.import_path in spec.mkdirs:
            return False

        for import_path_part in path_and_parent_paths(info.import_path):
            for spec2 in spec.load_path_infos:
                if import_path_part == spec2.import_path:
                    return False

        return True

    #     return create_specs[-1]

    for load_path_info in load_path_infos:
        create_spec = None
        for candidate in create_specs:
            if _should_add_load_path_info_to_spec(candidate, load_path_info):
                create_spec = candidate
                break

        if create_spec == None:
            create_spec = _new_create_spec()

        create_spec.load_path_infos.append(load_path_info)

        def _put_mkdir(x, load_path_info):
            # if not (x in create_spec.mkdirs):
            #     create_spec.mkdirs[x] = []
            # create_spec.mkdirs[x].append(load_path_info)
            create_spec.mkdirs[x] = True
            return x

        # mkdir all but the last directory. The last directory is a symlink
        # to load_path_info.directory
        mkdir_elements = _split_path(load_path_info.import_path)
        mkdir_elements.pop()
        if len(mkdir_elements) > 0:
            dir_to_make = _put_mkdir(mkdir_elements[0], load_path_info)

            for elem in mkdir_elements[1:]:
                dir_to_make = paths.join(dir_to_make, elem)
                _put_mkdir(dir_to_make, load_path_info)

        # Now
        # link_path = paths.join(dir_path, "load_path_i", load_path_info.import_path)
        # target_path_relative_to_link_path = _relative_path(
        #     load_path_info.directory.path,
        #     paths.dirname(link_path),
        # )

    def _create_spec_load_path_dir(i):
        if len(create_specs) > 1:
            return paths.join(dir_path, "load_path_{}".format(i))
        return dir_path

    return [
        struct(
            load_path = _create_spec_load_path_dir(i),
            mkdirs = sorted(spec.mkdirs.keys()),
            symlinks = [
                struct(
                    link_path = paths.join(_create_spec_load_path_dir(i), load_path_info.import_path),
                    target_path = _relative_path(
                        get_directory_path(load_path_info),
                        paths.dirname(
                            paths.join(
                                _create_spec_load_path_dir(i),
                                load_path_info.import_path,
                            ),
                        ),
                    ),
                )
                for load_path_info in spec.load_path_infos
            ],
        )
        for (i, spec) in enumerate(create_specs)
    ]

def path_and_parent_paths(p):
    """Given "foo/bar/baz", returns ["foo", "foo/bar", "foo/bar/baz"].

    Args:
        p: A unix-style path

    Returns:
        The top-most parent directory, the next-top-most parent directory,
        and so on.
    """
    elems = _split_path(p)
    all = [elems[0]]

    for elem in elems[1:]:
        all.append(paths.join(all[-1], elem))

    return all

def _split_path(p):
    elems = []

    for i in range(0, len(p) + 42):
        if p == "":
            break
        base = paths.basename(p)
        elems.extend([base])
        dir = paths.dirname(p)
        if dir == p:
            break
        p = dir

    return reversed(elems)
