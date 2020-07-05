'''Defines the `markdown_lint_aspect` Bazel aspect.

This aspect adds a lint as an action to `markdown` targets. The lint is
performed by the lint tool provided by the selected `markdown_lint_toolchain`.
'''

load("@dwtj_rules_markdown//markdown/rules/markdown_library:defs.bzl", "MarkdownInfo")

MarkdownLintAspectInfo = provider(
    fields = {
        # Will be `None` if the target can't be or shouldn't be linted.
        'output_file': 'The lint report file produced by `markdownlint`.',
    }
)

def _target_provides_markdown_info(target):
    return MarkdownInfo in target

def _map_file_to_its_path(file):
    return file.path

def _output_file_name_of(target):
    return target.label.name + ".markdownlint.log"

def _markdownlint_aspect_impl(target, aspect_ctx):
    # Skip a target if it doesn't provide `MarkdownInfo`:
    if not _target_provides_markdown_info(target):
        return [MarkdownLintAspectInfo()]

    # Extract information from the toolchain:
    toolchain = aspect_ctx.toolchains['@dwtj_rules_markdown//markdown/toolchains/markdownlint:toolchain_type']
    executable = toolchain.markdownlint_toolchain_info.markdownlint_executable
    toolchain_config_file = toolchain.markdownlint_toolchain_info.config_file

    # Extract information from the target markdown rule.
    srcs = target[MarkdownInfo].direct_source_files 
    target_config_file = target[MarkdownInfo].markdownlint_config_file

    # Override `config_file` with target's config file (if any).
    config_file = target_config_file \
            if target_config_file != None \
            else toolchain_config_file
 
    # Declare an output file located in the same package as the target and with
    # a name derived from the target's name.
    output_file = aspect_ctx.actions.declare_file(_output_file_name_of(target))

    # Construct an `actions.args()` object
    args = aspect_ctx.actions.args()

    # Add config file. (This doesn't add the flag if `config` is `None`.)
    args.add('--config', config_file.path)

    # Add output file and source files:
    args.add('--output', output_file)
    args.add_all(srcs, map_each = _map_file_to_its_path)

    # Build the set of input files: the source files plus the config (if any).
    input_files = srcs \
            if config_file == None \
            else depset([config_file], transitive = [srcs])
    
    # Create an action which runs `markdownlint` on the list of source files:
    aspect_ctx.actions.run(
        executable = executable,
        arguments = [args],
        inputs = input_files,
        outputs = [output_file],
        mnemonic = "MarkdownLint",
        use_default_shell_env = False,
    )

    return [
        OutputGroupInfo(default = [output_file]),
        MarkdownLintAspectInfo(output_file = output_file),
    ]

markdownlint_aspect = aspect(
    implementation = _markdownlint_aspect_impl,
    provides = [MarkdownLintAspectInfo],
    toolchains = ['@dwtj_rules_markdown//markdown/toolchains/markdownlint:toolchain_type'],
)
