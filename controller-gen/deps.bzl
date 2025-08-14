"""Controller-gen repositories and toolchains (WORKSPACE helper).

This macro defines external repositories to download controller-gen binaries
for the supported OS/architectures and registers the corresponding toolchains.

Args:
  version: Controller-tools release version to use (e.g. "0.17.1").
  arches: List of architectures to support (subset of ["amd64", "arm64"]).
"""

load("@rules_kubebuilder//controller-gen:repo.bzl", "controller_gen_download")

def _controller_gen_repo_name(os, arch):
    return "controller_gen_%s_%s" % (os, arch)

def controller_gen_register_toolchain(version = "0.17.1", arches = ["amd64", "arm64"]):
    for os in ["linux", "darwin"]:
        for arch in arches:
            repo_name = _controller_gen_repo_name(os, arch)
            controller_gen_download(
                name = repo_name,
                version = version,
                os = os,
                arch = arch,
            )

    # Register toolchains for each defined combo
    tcs = []
    if "amd64" in arches:
        tcs += [
            "@rules_kubebuilder//controller-gen:controller_gen_linux_amd64_toolchain",
            "@rules_kubebuilder//controller-gen:controller_gen_darwin_amd64_toolchain",
        ]
    if "arm64" in arches:
        tcs += [
            "@rules_kubebuilder//controller-gen:controller_gen_linux_arm64_toolchain",
            "@rules_kubebuilder//controller-gen:controller_gen_darwin_arm64_toolchain",
        ]

    if tcs:
        native.register_toolchains(*tcs)
