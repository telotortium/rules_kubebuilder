"""Bzlmod module extension for kustomize binaries."""

load("@rules_kubebuilder//kustomize:repo.bzl", "kustomize_download")

_kustomize_tag = tag_class(
    attrs = {
        "version": attr.string(default = "5.7.1"),
        "arches": attr.string_list(default = ["amd64", "arm64"]),
    },
)

def _kz_ext_impl(mctx):
    for mod in mctx.modules:
        for t in mod.tags.kustomize:
            for os in ["linux", "darwin"]:
                for arch in t.arches:
                    name = "kustomize_%s_%s" % (os, arch)
                    kustomize_download(name = name, version = t.version, os = os, arch = arch)

    names = []
    for mod in mctx.modules:
        for t in mod.tags.kustomize:
            for os in ["linux", "darwin"]:
                for arch in t.arches:
                    names.append("kustomize_%s_%s" % (os, arch))

    return mctx.extension_metadata(
        root_module_direct_deps = names,
        root_module_direct_dev_deps = [],
    )

kz_ext = module_extension(
    implementation = _kz_ext_impl,
    tag_classes = {"kustomize": _kustomize_tag},
)
