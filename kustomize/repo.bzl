"""Repository rule to download kustomize binaries by OS/arch."""

def _kustomize_url(version, os, arch):
    # Note: the tag path encodes the '/v' as '%2Fv' in release URLs.
    return (
        "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%%2Fv%s/kustomize_v%s_%s_%s.tar.gz" % (version, version, os, arch)
    )

def _write_build(repo_ctx):
    repo_ctx.file(
        "BUILD.bazel",
        content = """
package(default_visibility = ["//visibility:public"])
exports_files(["kustomize"])
""",
        executable = False,
    )

def _download_kustomize_impl(repo_ctx):
    version = repo_ctx.attr.version
    os = repo_ctx.attr.os
    arch = repo_ctx.attr.arch

    urls = repo_ctx.attr.urls
    if not urls:
        urls = [_kustomize_url(version, os, arch)]
    repo_ctx.download_and_extract(urls, stripPrefix = "")

    candidates = [
        "kustomize",
        "bin/kustomize",
        "kustomize_v%s_%s_%s/kustomize" % (version, os, arch),
    ]
    found = None
    for p in candidates:
        if repo_ctx.path(p).exists:
            found = p
            break
    if not found:
        fail("kustomize binary not found after extracting %s" % urls[0])

    if found != "kustomize":
        repo_ctx.symlink(found, "kustomize")

    _write_build(repo_ctx)

_download_kustomize = repository_rule(
    implementation = _download_kustomize_impl,
    attrs = {
        "version": attr.string(default = "5.7.1"),
        "os": attr.string(mandatory = True),
        "arch": attr.string(mandatory = True),
        "urls": attr.string_list(default = []),
    },
)

def kustomize_download(name, version, os, arch, urls = None):
    _download_kustomize(name = name, version = version, os = os, arch = arch, urls = urls or [])
