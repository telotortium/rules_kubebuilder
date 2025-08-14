"""Repository rule to download controller-gen binaries by OS/arch.

Provides a repository containing a single executable file `controller-gen` at
the repo root. Intended to be used by toolchain definitions.
"""

def _controller_gen_url(version, os, arch):
    return "https://github.com/kubernetes-sigs/controller-tools/releases/download/v%s/controller-gen-%s-%s" % (version, os, arch)

def _write_build(repo_ctx):
    repo_ctx.file(
        "BUILD.bazel",
        content = """
package(default_visibility = ["//visibility:public"])
exports_files(["controller-gen"])
""",
        executable = False,
    )

def _download_controller_gen_impl(repo_ctx):
    version = repo_ctx.attr.version
    os = repo_ctx.attr.os
    arch = repo_ctx.attr.arch

    urls = repo_ctx.attr.urls
    if not urls:
        urls = [_controller_gen_url(version, os, arch)]

    # Download the platform-specific binary directly as 'controller-gen'
    repo_ctx.download(urls, output = "controller-gen", executable = True)

    _write_build(repo_ctx)

_download_controller_gen = repository_rule(
    implementation = _download_controller_gen_impl,
    attrs = {
        "version": attr.string(default = "0.17.1"),
        "os": attr.string(mandatory = True),
        "arch": attr.string(mandatory = True),
        "urls": attr.string_list(default = []),
    },
)

def controller_gen_download(name, version, os, arch, urls = None):
    _download_controller_gen(name = name, version = version, os = os, arch = arch, urls = urls or [])
