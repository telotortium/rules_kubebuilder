"""Bzlmod module extension for controller-gen binaries.

Creates external repositories containing controller-gen binaries for
specified OS/arch combinations. Does not register toolchains.
"""

load("@rules_kubebuilder//controller-gen:repo.bzl", "controller_gen_download")

_controller_gen_tag = tag_class(
    attrs = {
        "version": attr.string(default = "0.17.1"),
        "arches": attr.string_list(default = ["amd64", "arm64"]),
        # Repos are always created for linux and darwin; override by adding/removing use_repo if needed
    },
)

def _cg_ext_impl(mctx):
    # For each module using this extension, create repos per requested arches
    for mod in mctx.modules:
        for t in mod.tags.controller_gen:
            for os in ["linux", "darwin"]:
                for arch in t.arches:
                    name = "controller_gen_%s_%s" % (os, arch)
                    controller_gen_download(name = name, version = t.version, os = os, arch = arch)

    # Surface created repo names for convenience
    names = []
    for mod in mctx.modules:
        for t in mod.tags.controller_gen:
            for os in ["linux", "darwin"]:
                for arch in t.arches:
                    names.append("controller_gen_%s_%s" % (os, arch))

    return mctx.extension_metadata(
        root_module_direct_deps = names,
        root_module_direct_dev_deps = [],
    )

cg_ext = module_extension(
    implementation = _cg_ext_impl,
    tag_classes = {"controller_gen": _controller_gen_tag},
)
