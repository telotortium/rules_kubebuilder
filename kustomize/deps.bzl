"""Kustomize repositories and toolchains (WORKSPACE helper).

This macro defines external repositories to download kustomize binaries
for the supported OS/architectures and registers the corresponding toolchains.

Args:
  version: Kustomize release version to use (e.g. "5.7.1").
  arches: List of architectures to support (subset of ["amd64", "arm64"]).
"""

load("@rules_kubebuilder//kustomize:repo.bzl", "kustomize_download")

def _kustomize_repo_name(os, arch):
    return "kustomize_%s_%s" % (os, arch)

def kustomize_register_toolchain(version = "5.7.1", arches = ["amd64", "arm64"]):
    for os in ["linux", "darwin"]:
        for arch in arches:
            kustomize_download(
                name = _kustomize_repo_name(os, arch),
                version = version,
                os = os,
                arch = arch,
            )

    tcs = []
    if "amd64" in arches:
        tcs += [
            "@rules_kubebuilder//kustomize:kustomize_linux_amd64_toolchain",
            "@rules_kubebuilder//kustomize:kustomize_darwin_amd64_toolchain",
        ]
    if "arm64" in arches:
        tcs += [
            "@rules_kubebuilder//kustomize:kustomize_linux_arm64_toolchain",
            "@rules_kubebuilder//kustomize:kustomize_darwin_arm64_toolchain",
        ]

    if tcs:
        native.register_toolchains(*tcs)
