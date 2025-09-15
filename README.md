# rules_kubebuilder

These bazel rules download and make available the [Kubebuilder SDK](https://github.com/kubernetes-sigs/kubebuilder) for building kubernetes operators in bazel.

## Installation

### Using with Bzlmod (MODULE.bazel)

With Bzlmod, repository creation and toolchain registration must be separated:

- Module extensions may create external repositories but may not call `register_toolchains()`.
- Toolchains must be registered in the root `MODULE.bazel` via the `register_toolchains(...)` directive.

This repo provides module extensions to download the Kubebuilder SDK, controller-gen, and kustomize. Register the toolchains directly using labels from this repo.

Note: Recent Kubebuilder releases only include the `kubebuilder` binary in the SDK tarball. The `etcd`, `kube-apiserver`, and `kubectl` binaries are not bundled and must be provided separately. Collect these binaries into a single directory at runtime and set `KUBEBUILDER_ASSETS` to that directory for tests that use envtest.

Example `MODULE.bazel` snippet:

```starlark
module(name = "your_module")

bazel_dep(name = "rules_kubebuilder", version = "0.1.0")

# Create the SDK repo(s) via the module extension
kb = use_extension("@rules_kubebuilder//kubebuilder:extensions.bzl", "kb_ext")
kb.kubebuilder_sdk(name = "kubebuilder_sdk_4_8_0", version = "4.8.0")
use_repo(kb, "kubebuilder_sdk_4_8_0")

# Download controller-gen binaries for both arches
cg = use_extension("@rules_kubebuilder//controller-gen:extensions.bzl", "cg_ext")
cg.controller_gen(version = "0.17.1", arches = ["amd64", "arm64"])  # creates repos named controller_gen_<os>_<arch>
use_repo(cg,
  "controller_gen_linux_amd64",
  "controller_gen_linux_arm64",
  "controller_gen_darwin_amd64",
  "controller_gen_darwin_arm64",
)

# Download kustomize binaries for both arches
kz = use_extension("@rules_kubebuilder//kustomize:extensions.bzl", "kz_ext")
kz.kustomize(version = "5.7.1", arches = ["amd64", "arm64"])  # creates repos named kustomize_<os>_<arch>
use_repo(kz,
  "kustomize_linux_amd64",
  "kustomize_linux_arm64",
  "kustomize_darwin_amd64",
  "kustomize_darwin_arm64",
)

# Register toolchains at the root (don’t do this from an extension)
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
```

Note: The macros in `controller-gen/deps.bzl` and `kustomize/deps.bzl` call `native.register_toolchains(...)` and are intended for WORKSPACE-based setups. Do not call these macros from a module extension.

### WORKSPACE (legacy Bazel, obsolete from Bazel 8.0+)

To use these rules, add the following to your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "rules_kubebuilder",
    branch = "main",
    remote = "https://github.com/ob/rules_kubebuilder.git",
)

load("@rules_kubebuilder//kubebuilder:sdk.bzl", "kubebuilder_register_sdk")

kubebuilder_register_sdk(version = "4.8.0")

load("@rules_kubebuilder//controller-gen:deps.bzl", "controller_gen_register_toolchain")
load("@rules_kubebuilder//kustomize:deps.bzl", "kustomize_register_toolchain")

# Downloads binaries from GitHub for linux/darwin and amd64/arm64 by default,
# and registers the matching toolchains.
controller_gen_register_toolchain(version = "0.17.1", arches = ["amd64", "arm64"])  # controller-gen
kustomize_register_toolchain(version = "5.7.1", arches = ["amd64", "arm64"])       # kustomize
```

## Kubebuilder tests

In your `go_test()` rules, include your asset binaries as data and set
`KUBEBUILDER_ASSETS` for the test itself. For example:

```starlark
go_test(
    name = "go_default_test",
    srcs = ["apackage_test.go"],
    # Provide your own binaries (e.g., go_binary targets or prebuilt files)
    data = [
        ":etcd_bin",
        ":kube_apiserver_bin",
        ":kubectl_bin",
    ],
    # Point this to a directory on disk or an output created by your build.
    # For example, you can assemble a directory via a genrule and reference
    # its path here, or keep a stable path in your repo.
    env = {"KUBEBUILDER_ASSETS": "/path/to/your/assets/dir"},
    embed = [":go_default_library"],
)
```

Alternatively, you can pass the environment variable on the command line:

```shell
bazel test --test_env=KUBEBUILDER_ASSETS=/path/to/your/assets/dir //...
```

### Macro: Assemble envtest assets

To make assembling assets easier, this repo includes a small macro that copies
your binaries into a single directory and provides a helper to print that path.

```starlark
load("@rules_kubebuilder//kubebuilder:assets.bzl", "kubebuilder_assets")

# Assume you build or provide these binaries somewhere in your repo
# (they can be go_binary targets or prebuilt files).
kubebuilder_assets(
    name = "envtest",  # creates etcd, kube-apiserver, kubectl, and envtest_assets_pwd
    etcd = ":etcd_bin",
    kube_apiserver = ":kube_apiserver_bin",
    kubectl = ":kubectl_bin",
)

# In CI or locally, set KUBEBUILDER_ASSETS using the helper (prints the
# directory containing the assembled etcd/kube-apiserver/kubectl files):
#   bazel test --test_env=KUBEBUILDER_ASSETS=$(bazel run //path:envtest_assets_pwd) //...
```

You can also add the following to `BUILD.bazel` at the root of your workspace:

```starlark
load("@rules_kubebuilder//kubebuilder:def.bzl", "kubebuilder")
kubebuilder(name = "kubebuilder")
```

to be able to run `kubebuilder` like so:

```shell
bazel run //:kubebuilder -- --help
```

## Controller-gen

In order to use `controller-gen` you will need to do something like the following in your `api/v1alpha1` directory (essentially where the `*_type.go` files are):

```starlark
load("@rules_go//go:def.bzl", "go_library")
load(
    "@rules_kubebuilder//controller-gen:controller-gen.bzl",
    "controller_gen_crd",
    "controller_gen_object",
    "controller_gen_rbac",
)

filegroup(
    name = "srcs",
    srcs = [
        "groupversion_info.go",
        # your source files here, except for zz_generated_deepcopy.go
    ],
)

DEPS = [
    "@io_k8s_api//core/v1:go_default_library",
    "@io_k8s_apimachinery//pkg/api/resource:go_default_library",
    "@io_k8s_apimachinery//pkg/apis/meta/v1:go_default_library",
    "@io_k8s_apimachinery//pkg/runtime:go_default_library",
    "@io_k8s_apimachinery//pkg/runtime/schema:go_default_library",
    "@io_k8s_sigs_controller_runtime//pkg/scheme:go_default_library",
]

controller_gen_object(
    name = "generated_sources",
    srcs = [
        ":srcs",
    ],
    deps = DEPS,
)

go_library(
    name = "go_default_library",
    # keep
    srcs = [
        ":generated_sources",
        ":srcs",
    ],
    importpath = "yourdomain.com/your-operator/api/v1alpha1",
    visibility = ["//visibility:public"],
    # keep
    deps = DEPS,
)

controller_gen_crd(
    name = "crds",
    srcs = [
        ":srcs",
    ],
    visibility = ["//visibility:public"],
    deps = DEPS,
)
```

The `deps` passed to the `controller_gen_*` rules are converted to a GOPATH
using the `go_path` rule from `@rules_go//go:def.bzl`. For more complex use
cases, you can instead pass a target derived from a `go_path` rule as the
`gopath_dep` argument. This can be useful if you need to run controller-gen
using Go source files from many directories. The above example translated to
use `gopath_dep` is as follows:

```starlark
load("@rules_go//go:def.bzl", "go_library", "go_path")
load(
    "@rules_kubebuilder//controller-gen:controller-gen.bzl",
    "controller_gen_crd",
    "controller_gen_object",
    "controller_gen_rbac",
)

DEPS = [
    "@io_k8s_api//core/v1:go_default_library",
    "@io_k8s_apimachinery//pkg/api/resource:go_default_library",
    "@io_k8s_apimachinery//pkg/apis/meta/v1:go_default_library",
    "@io_k8s_apimachinery//pkg/runtime:go_default_library",
    "@io_k8s_apimachinery//pkg/runtime/schema:go_default_library",
    "@io_k8s_sigs_controller_runtime//pkg/scheme:go_default_library",
]

filegroup(
    name = "srcs",
    srcs = glob(["*.go"], exclude=["*_test.go"]),
)

go_path(
    name = "gopath",
    deps = [":go_default_library"],
)

controller_gen_object(
    name = "generated_sources",
    srcs = [
        ":srcs",
    ],
    # Still must pass deps to `controller_gen_object`, since
    # `:go_default_library` needs the output of this rule to build.
    deps = DEPS,
)

go_library(
    name = "go_default_library",
    # keep
    srcs = [
        ":generated_sources",
        ":srcs",
    ],
    importpath = "yourdomain.com/your-operator/api/v1alpha1",
    visibility = ["//visibility:public"],
    # keep
    deps = DEPS,
)

controller_gen_crd(
    name = "crds",
    srcs = [
        ":srcs",
    ],
    visibility = ["//visibility:public"],
    # But non-object dependencies can use `:gopath` instead.
    gopath_dep = ":gopath",
)

controller_gen_rbac(
    name = "rbacs",
    srcs = [
        ":srcs",
    ],
    visibility = ["//visibility:public"],
    # But non-object dependencies can use `:gopath` instead.
    gopath_dep = ":gopath",
)
```

## Kustomize

This repo also exposes a rule `kustomize` to run basic Kustomize commands, as
well as a `kustomize_bin` target to use from genrules to run arbitrary
Kustomize commands:

```starlark
@load("rules_kubebuilder//kustomize:kustomize.bzl", "kustomize")
kustomize(
    name = "example",
    srcs = ["kustomization.yaml", "base.yaml"],
)
genrule(
    name = "example_genrule",
    srcs = ["kustomization.yaml", "base.yaml"],
    outs = ["rendered.yaml"],
    cmd = """
set -e
$(location @rules_kubebuilder//kustomize:kustomize_bin) build \
    --load-restrictor=LoadRestrictionsNone $(SRCS) > $@
""",
    tools = ["@rules_kubebuilder//kustomize:kustomize_bin"],
)
```

## Historical Notes

Previously this repo committed prebuilt binaries for controller-gen and kustomize.
This has been replaced with repository rules that download the official release
artifacts from GitHub at fetch time. No binaries are stored in Git, and arm64
is supported alongside amd64.
