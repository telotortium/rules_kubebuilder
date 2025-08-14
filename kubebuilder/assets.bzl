"""Utilities to assemble envtest assets into a single directory.

This macro copies user-provided etcd, kube-apiserver, and kubectl binaries
into a single output directory suitable for use as KUBEBUILDER_ASSETS.

It also creates a `<name>_assets_pwd` executable that prints the directory path,
so you can set KUBEBUILDER_ASSETS via:

  bazel run //path:NAME_assets_pwd
"""

load("@rules_kubebuilder//kubebuilder:sdk.bzl", "kubebuilder_pwd")

def kubebuilder_assets(name, *, etcd, kube_apiserver, kubectl, visibility = None):
    """Assemble envtest assets into a single directory.

    Args:
      name: Base name for generated targets.
      etcd: Label of etcd binary.
      kube_apiserver: Label of kube-apiserver binary.
      kubectl: Label of kubectl binary.
      visibility: Optional visibility list applied to created targets.

    Creates:
      - genrule `name + "_assets"` producing files under `<name>_assets/`:
          - `<name>_assets/etcd`
          - `<name>_assets/kube-apiserver`
          - `<name>_assets/kubectl`
      - target `name + "_assets_pwd"` printing the directory path
    """

    if visibility == None:
        visibility = ["//visibility:public"]

    # Place outputs in the package's bin directory with canonical filenames
    # expected by envtest. Keeping them in the same directory allows
    # KUBEBUILDER_ASSETS to be set to that directory.
    out_etcd = "etcd"
    out_kas = "kube-apiserver"
    out_kubectl = "kubectl"

    native.genrule(
        name = name + "_assets",
        srcs = [],
        tools = [
            etcd,
            kube_apiserver,
            kubectl,
        ],
        outs = [
            out_etcd,
            out_kas,
            out_kubectl,
        ],
        # All outs live under the same directory; $(@D) resolves to that dir
        # for the first output.
        cmd = (
            "mkdir -p $(@D) && " +
            "cp $(location {etcd}) $(@D)/{out_etcd} && " +
            "cp $(location {kas}) $(@D)/{out_kas} && " +
            "cp $(location {kubectl}) $(@D)/{out_kubectl}"
        ).format(
            etcd = etcd,
            kas = kube_apiserver,
            kubectl = kubectl,
            out_etcd = out_etcd,
            out_kas = out_kas,
            out_kubectl = out_kubectl,
        ),
        visibility = visibility,
    )

    # Create a helper that prints the assembled directory path.
    kubebuilder_pwd(
        name = name + "_assets_pwd",
        srcs = [":" + out_etcd],
        kubebuilder_binary = ":" + out_etcd,
        visibility = visibility,
    )
