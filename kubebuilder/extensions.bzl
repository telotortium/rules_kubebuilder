"""Bzlmod module extension for kubebuilder SDK.

This extension only creates external repositories (downloads the SDK).
It does NOT register toolchains. In Bzlmod, register toolchains in the
root MODULE.bazel using `register_toolchains(...)` with the labels from
this repo (e.g. @rules_kubebuilder//controller-gen:..., @rules_kubebuilder//kustomize:...).

Example usage in MODULE.bazel:

  bazel_dep(name = "rules_kubebuilder", version = "0.1.0")

  kb = use_extension("@rules_kubebuilder//kubebuilder:extensions.bzl", "kb_ext")
  kb.kubebuilder_sdk(name = "kubebuilder_sdk_4_8_0", version = "4.8.0")
  use_repo(kb, "kubebuilder_sdk_4_8_0")

  # Register toolchains at the root (do NOT call from an extension)
  register_toolchains(
      # controller-gen
      "@rules_kubebuilder//controller-gen:controller_gen_linux_amd64_toolchain",
      "@rules_kubebuilder//controller-gen:controller_gen_linux_arm64_toolchain",
      "@rules_kubebuilder//controller-gen:controller_gen_darwin_amd64_toolchain",
      "@rules_kubebuilder//controller-gen:controller_gen_darwin_arm64_toolchain",
      # kustomize
      "@rules_kubebuilder//kustomize:kustomize_linux_amd64_toolchain",
      "@rules_kubebuilder//kustomize:kustomize_linux_arm64_toolchain",
      "@rules_kubebuilder//kustomize:kustomize_darwin_amd64_toolchain",
      "@rules_kubebuilder//kustomize:kustomize_darwin_arm64_toolchain",
  )
"""

load("@rules_kubebuilder//kubebuilder:sdk.bzl", "kubebuilder_download_sdk")

_kubebuilder_sdk_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        # Future: add urls/strip_prefix overrides if needed
    },
)

def _kb_ext_impl(mctx):
    # Create requested SDK repos during module resolution
    for mod in mctx.modules:
        for t in mod.tags.kubebuilder_sdk:
            kubebuilder_download_sdk(
                name = t.name,
                version = t.version,
            )

    # Optionally, guide Bazel on likely imports (for editor UX only)
    return mctx.extension_metadata(
        root_module_direct_deps = [t.name for mod in mctx.modules for t in mod.tags.kubebuilder_sdk],
        root_module_direct_dev_deps = [],
    )

kb_ext = module_extension(
    implementation = _kb_ext_impl,
    tag_classes = {
        "kubebuilder_sdk": _kubebuilder_sdk_tag,
    },
)
