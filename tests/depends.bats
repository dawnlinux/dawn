#!/usr/bin/env bats
#
# The package manifest and the PKGBUILD's depends array must agree. They are
# two files that encode the same fact, so something has to enforce it.

setup() {
    REPO="$BATS_TEST_DIRNAME/.."
    CHECK="$REPO/packaging/check-depends.sh"
}

@test "check passes when the PKGBUILD matches the manifest" {
    run "$CHECK"
    [ "$status" -eq 0 ]
}

@test "check fails when the manifest gains a package the PKGBUILD lacks" {
    cp "$REPO/install/packages.txt" "$BATS_TMPDIR/packages.bak"
    echo "cowsay   # deliberately not in the PKGBUILD" >> "$REPO/install/packages.txt"

    run "$CHECK"
    status_saved="$status"
    output_saved="$output"
    cp "$BATS_TMPDIR/packages.bak" "$REPO/install/packages.txt"

    [ "$status_saved" -ne 0 ]

    # Naming the offending package matters: a bare non-zero exit cannot be
    # told apart from the script being missing or crashing, which would make
    # this test pass for entirely the wrong reason.
    [[ "$output_saved" == *"cowsay"* ]]
}

@test "check fails loudly when the PKGBUILD is missing entirely" {
    # Distinguishes "drift detected" from "cannot check at all". Exit 2 is
    # reserved for the latter so CI can tell them apart.
    run env DAWN_PKGBUILD=/nonexistent/PKGBUILD "$CHECK"
    [ "$status" -eq 2 ]
    [[ "$output" == *"missing"* ]]
}
