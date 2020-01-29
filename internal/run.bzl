_DOCKER_TOOLCHAIN = "@io_bazel_rules_docker//toolchains/docker:toolchain_type"

def _impl(
        ctx,
        name = None,
        image = None,
        docker_run_flags = None,
        output_image_tar = None):
    """Implementation for the container_run_and_commit rule.
    This rule runs a set of commands in a given image, waits for the commands
    to finish, and then commits the container to a new image.
    Args:
        ctx: The bazel rule context
        name: A unique name for this rule.
        image: The input image tarball
        commands: The commands to run in the input image container
        docker_run_flags: String list, overrides ctx.attr.docker_run_flags
    """

    name = name or ctx.attr.name
    image = image or ctx.file.image
    docker_run_flags = docker_run_flags or ctx.attr.docker_run_flags
    toolchain_info = ctx.toolchains[_DOCKER_TOOLCHAIN].info
    # Generate a shell script to execute the run statement
    run_script = ctx.actions.declare_file(name + ".run")
    image_id = ctx.actions.declare_file(name + ".image_id")

    runfiles = [image, image_id]

    ctx.actions.run_shell(
        outputs = [image_id],
        inputs = [image],
        command = "$1 $2 > $3",
        tools = [ctx.executable._extract_image_id],
        use_default_shell_env = True,
        arguments = [ctx.executable._extract_image_id.path, image.path, image_id.path]
    )

    ctx.actions.expand_template(
        template = ctx.file._run_tpl,
        output = run_script,
        substitutions = {
            "%{docker_flags}": " ".join(toolchain_info.docker_flags),
            "%{docker_run_flags}": " ".join(docker_run_flags),
            "%{docker_tool_path}": toolchain_info.tool_path,
            "%{image_id}": "cat %s" % image_id.short_path,
            "%{image_tar}": image.short_path,
        },
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = runfiles,
            ),
            executable = run_script
        ),
    ]

container_run = rule(
    implementation = _impl,
    executable = True,
    attrs = {
        "image": attr.label(
            allow_single_file = [".tar"],
            mandatory = True,
            doc = "The label of the image to push.",
        ),
        "docker_run_flags": attr.string_list(
            doc = "Extra flags to pass to the docker run command.",
            mandatory = False,
            default = [""]
        ),
        "_run_tpl": attr.label(
            default = Label("//internal:run.sh.tpl"),
            allow_single_file = True,
        ),
        "_extract_image_id": attr.label(
            default = Label("@io_bazel_rules_docker//contrib:extract_image_id"),
            cfg = "target",
            executable = True,
            allow_files = True,
        ),
    },
    toolchains = [_DOCKER_TOOLCHAIN],
)
