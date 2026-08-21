#!/usr/bin/env bash
#
# Every wallpaper × every scheme, checked against WCAG AA.
#
# This is the test that stops a future mapping or scheme change from quietly
# making the desktop unreadable. Material You's tonal system is supposed to
# guarantee legible on-surface pairs by construction; this verifies that rather
# than trusting it, across the actual images on this machine.
#
#     ./tests/contrast-sweep.sh [wallpaper-dir]
#
# Exit codes are distinct so CI can tell the two apart:
#
#     0   every pair is at or above the floor
#     1   at least one pair is below it, or matugen failed on an image
#     2   the sweep could not run (matugen missing, no images)

set -euo pipefail

DIR="${1:-$HOME/Pictures/Wallpapers}"
FLOOR="${DAWN_CONTRAST_FLOOR:-4.5}"

command -v matugen >/dev/null || { echo "matugen not installed" >&2; exit 2; }
[ -d "$DIR" ] || { echo "no wallpaper directory: $DIR" >&2; exit 2; }

python3 - "$DIR" "$FLOOR" <<'PY'
import json, subprocess, sys, pathlib

wall_dir, floor = pathlib.Path(sys.argv[1]), float(sys.argv[2])

SCHEMES = ["tonal-spot", "vibrant", "expressive", "content", "fidelity",
           "neutral", "monochrome", "rainbow", "fruit-salad"]

# Dawn role -> the Material You role it is mapped from, for every pair that
# renders text or a marker directly on `background`. Kept in step with
# config/matugen/templates/dawn-colors.json by hand; a role added there that
# sits on the background should be added here too.
PAIRS = {
    "text":          "on_surface",
    "textSecondary": "on_surface_variant",
    "textTertiary":  "outline",
    "accentBase":    "primary",
    "danger":        "error",
}
BACKGROUND = "surface"

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}


def luminance(hex_colour):
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


images = sorted(p for p in wall_dir.iterdir()
                if p.is_file() and p.suffix.lower() in EXTS)
if not images:
    print(f"no images in {wall_dir}", file=sys.stderr)
    sys.exit(2)

checked = failures = 0
worst = (99.0, "")

for image in images:
    for scheme in SCHEMES:
        run = subprocess.run(
            ["matugen", "-j", "hex", "--dry-run", "--prefer", "saturation",
             "-t", f"scheme-{scheme}", "image", str(image)],
            capture_output=True, text=True)

        if run.returncode != 0 or not run.stdout.strip():
            detail = run.stderr.strip().splitlines()
            detail = detail[-1] if detail else "no output"
            print(f"FAIL  matugen errored on {image.name} / {scheme}: {detail}",
                  file=sys.stderr)
            failures += 1
            continue

        colours = json.loads(run.stdout)["colors"]
        background = colours[BACKGROUND]["dark"]["color"]

        for role, md3 in PAIRS.items():
            ratio = contrast(colours[md3]["dark"]["color"], background)
            checked += 1
            if ratio < worst[0]:
                worst = (ratio, f"{image.name} / {scheme} / {role}")
            if ratio < floor:
                print(f"FAIL  {ratio:.2f} < {floor}  "
                      f"{image.name} / {scheme} / {role}", file=sys.stderr)
                failures += 1

print(f"checked {checked} contrast pairs "
      f"({len(images)} wallpapers x {len(SCHEMES)} schemes x {len(PAIRS)} roles)")
print(f"worst:   {worst[0]:.2f}  ({worst[1]})")
print(f"below {floor}: {failures}")

sys.exit(1 if failures else 0)
PY
