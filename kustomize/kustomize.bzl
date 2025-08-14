""" Rules to run kustomize
"""

def _kustomize_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".yaml")
    tmpdir = ctx.actions.declare_directory(ctx.label.name + ".tmp")
    kustomize_info = ctx.toolchains["@rules_kubebuilder//kustomize:toolchain"].kustomize_info

    ctx.actions.run_shell(
        mnemonic = "Kustomize",
        outputs = [output, tmpdir],
        inputs = ctx.files.srcs,
        command = """
        mkdir -p {tmp_path} &&
        cp {srcs} {tmp_path} &&
        {kustomize} build {tmp_path} > {output}
        """.format(
            kustomize = kustomize_info.kustomize_bin.path,
            srcs = " ".join(['"{}"'.format(f.path) for f in ctx.files.srcs]),
            tmp_path = tmpdir.short_path,
            output = output.path,
        ),
        tools = [
            kustomize_info.kustomize_bin,
        ],
    )

    return DefaultInfo(
        files = depset([output]),
    )

kustomize = rule(
    implementation = _kustomize_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_empty = False,
            allow_files = True,
            mandatory = True,
            doc = "Source files passed to kustomize",
        ),
    },
    toolchains = [
        "@rules_kubebuilder//kustomize:toolchain",
    ],
    doc = "",
)

def _kustomize_bin_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    kustomize_info = ctx.toolchains["@rules_kubebuilder//kustomize:toolchain"].kustomize_info

    script = _make_script(kustomize_info.kustomize_bin.path)

    ctx.actions.write(output = out, content = script, is_executable = True)

    # Merge runfiles: (a) your tool, (b) the bash runfiles lib’s runfiles
    rf = ctx.runfiles(files = [kustomize_info.kustomize_bin])
    rf = rf.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    return DefaultInfo(
        files = depset([out]),
        executable = out,
        runfiles = rf,
    )

def _make_script(path):
    no_external = path
    if path.startswith("external/"):
        no_external = path[len("external/"):]
    return """#!/usr/bin/env bash
set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${{RUNFILES_DIR:-/dev/null}}/$f" 2>/dev/null || \
source "$(grep -sm1 "^$f " "${{RUNFILES_MANIFEST_FILE:-/dev/null}}" | cut -f2- -d' ')" 2>/dev/null || \
source "$0.runfiles/$f" 2>/dev/null || \
source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
{{ echo>&2 "ERROR: cannot find $f"; exit 1; }}; f=; set -e
# --- end runfiles.bash initialization v3 ---

tool="$(rlocation "{runfile1}")"
if [[ -z "${{tool:-}}" || ! -x "${{tool:-}}" ]]; then
  tool="$(rlocation "{runfile2}")"
fi
if [[ -z "${{tool:-}}" || ! -x "${{tool:-}}" ]]; then
  echo "ERROR: kustomize binary not found in runfiles: tried {runfile1} and {runfile2}" >&2
  exit 1
fi
exec "${{tool?}}" "$@"
""".format(runfile1 = no_external, runfile2 = path)

kustomize_bin = rule(
    implementation = _kustomize_bin_impl,
    attrs = {
        # Pull in the Bash runfiles library
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    toolchains = ["@rules_kubebuilder//kustomize:toolchain"],
    executable = True,
    doc = "Executable wrapper that runs the kustomize binary from the active toolchain.",
)
