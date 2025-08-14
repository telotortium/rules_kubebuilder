package apackage

import (
    "os"
    "os/exec"
    "strings"
    "testing"

    "github.com/bazelbuild/rules_go/go/runfiles"
)

func TestAFunct(t *testing.T) {
	err := Afunc(true)
	if err != nil {
		t.Errorf("Should have worked")
	}
}

// See https://pkg.go.dev/sigs.k8s.io/controller-runtime/pkg/envtest
func TestEnvironment(t *testing.T) {
    // Demonstrate end-to-end usage of the kubebuilder_assets macro by
    // locating and running the generated *_assets_pwd helper to obtain
    // the assembled assets directory, then setting KUBEBUILDER_ASSETS.
    rf, err := runfiles.New()
    if err != nil {
        t.Fatalf("runfiles.New(): %v", err)
    }
    ws := os.Getenv("TEST_WORKSPACE")
    if ws == "" {
        ws = "rules_kubebuilder"
    }
    helperPath, err := rf.Rlocation(ws + "/test/envtest_assets_pwd.bash")
    if err != nil {
        t.Fatalf("Rlocation: %v", err)
    }
    out, err := exec.Command(helperPath).CombinedOutput()
    if err != nil {
        t.Fatalf("running envtest_assets_pwd: %v, out=%s", err, string(out))
    }
    dir := strings.TrimSpace(string(out))
    if dir == "" {
        t.Fatalf("envtest_assets_pwd returned empty path")
    }
    if err := os.Setenv("KUBEBUILDER_ASSETS", dir); err != nil {
        t.Fatalf("Setenv: %v", err)
    }

    kbAssets := os.Getenv("KUBEBUILDER_ASSETS")
    if kbAssets == "" {
        t.Errorf("Did not find KUBEBUILDER_ASSETS environment variable set")
    }

}
