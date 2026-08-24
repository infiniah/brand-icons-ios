#!/usr/bin/env python3
"""Regenerate Sources/BrandIcons/Resources/BrandMarks.json from Simple Icons.

Bundles every icon the Simple Icons npm package ships. The package used to carry a curated
few hundred, on the assumption that the rest would come from a CDN at runtime. Measurement
killed that: a mark costs about a kilobyte raw and under half a kilobyte once the App Store
compresses the binary, so the whole set is a small download in exchange for a catalogue that
never misses and never opens a socket.

The metadata file carries each brand's title, colour and, where the project has recorded
one, the licence the icon itself is offered under. The SVGs carry the geometry.

An icon is skipped only when it is not a single filled path, because that is the one shape
this package can draw. Every skip is reported rather than swallowed.

Simple Icons removes brands on request, so regenerating can drop marks that a previous run
included. The counts printed at the end are the way to notice.

    python3 Scripts/generate_marks.py
    python3 Scripts/generate_marks.py --version 16.28.0

Read NOTICE before shipping any of these marks. CC0 covers copyright in the drawing. It
does not touch the trademark, and some icons carry a licence other than CC0.

Needs network access.
"""

import argparse
import io
import json
import os
import re
import sys
import tarfile
import urllib.request

REGISTRY = "https://registry.npmjs.org/simple-icons"
LOGOS_REGISTRY = "https://registry.npmjs.org/@iconify-json/logos"

# Simple Icons is monochrome by design: one path, one colour. That is the right call for a
# uniform set and the wrong picture for a brand whose identity *is* colour, where the mark
# comes out a flat silhouette or, as with Figma, a hollow outline.
#
# gilbarbara's SVG Logos is CC0 as well and carries the real multi colour artwork, plus a few
# hundred brands Simple Icons has removed on trademark request. Marks from it are attached to
# the matching Simple Icons entry as `layers`, so the catalogue keeps one row per brand.
#
# Only the marks this package can actually draw are taken: a gradient, a mask or a clip path
# needs a renderer this does not have, and a wordmark is the wrong shape for an icon slot.
LOGOS_MAX_ASPECT = 2.0
USER_AGENT = "BrandIconsMarkGenerator/1.0"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "Sources", "BrandIcons", "Resources", "BrandMarks.json")

VIEW_BOX = re.compile(r'viewBox="([^"]+)"')
PATH_DATA = re.compile(r'\sd="([^"]+)"')
LOGOS_ELEMENT = re.compile(r"<([a-zA-Z]+)")
LOGOS_PATH = re.compile(r"<path([^>]*?)/?>")
LOGOS_D = re.compile(r'\sd="([^"]+)"')
LOGOS_FILL = re.compile(r'fill="(#[0-9A-Fa-f]{3,8})"')
LOGOS_UNDRAWABLE = ("url(#", "<defs", "clipPath", "mask", "stroke=")


def request(url):
    return urllib.request.Request(url, headers={"User-Agent": USER_AGENT})


def resolve_version(requested):
    if requested:
        return requested
    with urllib.request.urlopen(request(f"{REGISTRY}/latest"), timeout=60) as response:
        return json.load(response)["version"]


def download_package(version):
    url = f"{REGISTRY}/-/simple-icons-{version}.tgz"
    print(f"fetching {url}", file=sys.stderr)
    with urllib.request.urlopen(request(url), timeout=300) as response:
        payload = response.read()
    return tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz")


def read_member(archive, name):
    member = archive.extractfile(name)
    if member is None:
        return None
    return member.read().decode("utf-8")


def parse_svg(svg):
    """Returns (path data, viewBox) or None when the SVG is not a single filled path."""
    paths = PATH_DATA.findall(svg)
    if len(paths) != 1:
        return None

    box = VIEW_BOX.search(svg)
    if not box:
        return None
    numbers = [float(part) for part in re.split(r"[\s,]+", box.group(1).strip()) if part]
    if len(numbers) != 4 or numbers[2] <= 0 or numbers[3] <= 0:
        return None

    return paths[0].strip(), numbers


def download_logos():
    """The SVG Logos set, as Iconify publishes it."""
    with urllib.request.urlopen(request(f"{LOGOS_REGISTRY}/latest"), timeout=60) as response:
        version = json.load(response)["version"]
    url = f"{LOGOS_REGISTRY}/-/logos-{version}.tgz"
    print(f"fetching {url}", file=sys.stderr)
    with urllib.request.urlopen(request(url), timeout=300) as response:
        payload = response.read()
    archive = tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz")
    icons = json.loads(read_member(archive, "package/icons.json"))
    archive.close()
    return version, icons


def logos_layers(body):
    """The fill coloured paths of one icon, or None when it needs a renderer we do not have."""
    if set(LOGOS_ELEMENT.findall(body)) != {"path"}:
        return None
    if any(token in body for token in LOGOS_UNDRAWABLE):
        return None

    layers = []
    for match in LOGOS_PATH.finditer(body):
        attributes = match.group(1)
        path = LOGOS_D.search(attributes)
        if not path:
            continue
        fill = LOGOS_FILL.search(attributes)
        layers.append(
            {"path": path.group(1).strip(), "fill": fill.group(1).lstrip("#").upper() if fill else None}
        )
    return layers or None


def logos_key(slug):
    """`spotify-icon` and `spotify` are the same brand, and match Simple Icons' `spotify`."""
    return slug.removesuffix("-icon").replace("-", "").replace(".", "").lower()


def logos_title(slug):
    """A readable name from a slug, used only when Simple Icons has no entry to borrow from.

    The set ships no titles, so this is a guess. It only has to be good enough to score
    against, since matching normalises both sides anyway.
    """
    return " ".join(part.capitalize() for part in slug.removesuffix("-icon").split("-"))


def build_color_marks():
    """Colour marks keyed the way Simple Icons slugs normalise, best variant per brand."""
    version, icons = download_logos()
    default_width = icons.get("width", 24)
    default_height = icons.get("height", 24)

    chosen = {}
    skipped_undrawable = 0
    skipped_shape = 0

    for slug, icon in icons.get("icons", {}).items():
        # Iconify keeps deprecated marks in the set behind this flag.
        if icon.get("hidden"):
            continue
        width = icon.get("width", default_width)
        height = icon.get("height", default_height)
        if width <= 0 or height <= 0:
            continue
        if max(width, height) / min(width, height) > LOGOS_MAX_ASPECT:
            skipped_shape += 1
            continue

        layers = logos_layers(icon["body"])
        if layers is None:
            skipped_undrawable += 1
            continue

        key = logos_key(slug)
        candidate = {
            "slug": slug,
            "title": logos_title(slug),
            "viewBox": [0.0, 0.0, float(width), float(height)],
            "layers": layers,
        }
        # `spotify-icon` is the square mark and `spotify` is the wordmark, so when both survive
        # the aspect filter the squarer one is the icon.
        previous = chosen.get(key)
        if previous is None:
            chosen[key] = candidate
        else:
            def squareness(entry):
                _, _, w, h = entry["viewBox"]
                return max(w, h) / min(w, h)
            if squareness(candidate) < squareness(previous):
                chosen[key] = candidate

    return version, chosen, skipped_undrawable, skipped_shape


def build(version):
    archive = download_package(version)
    metadata = json.loads(read_member(archive, "package/data/simple-icons.json"))

    marks = []
    missing = []
    unreadable = []

    for icon in metadata:
        slug = icon.get("slug")
        if not slug:
            continue

        svg = read_member(archive, f"package/icons/{slug}.svg")
        if svg is None:
            missing.append(slug)
            continue

        parsed = parse_svg(svg)
        if parsed is None:
            unreadable.append(slug)
            continue

        path_data, view_box = parsed
        mark = {
            "slug": slug,
            "title": icon["title"],
            "path": path_data,
            "viewBox": view_box,
            "tint": icon["hex"],
        }

        # Carried through rather than dropped: a licence other than CC0 changes what a
        # user of this package is agreeing to. See NOTICE.
        license_info = icon.get("license")
        if isinstance(license_info, dict) and license_info.get("type"):
            entry = {"type": license_info["type"]}
            if license_info.get("url"):
                entry["url"] = license_info["url"]
            mark["license"] = entry

        marks.append(mark)

    archive.close()
    marks.sort(key=lambda mark: mark["slug"])
    return marks, len(metadata), missing, unreadable


def merge_color(marks, color_marks):
    """Attach colour artwork to the brand it belongs to, and add the brands only it has."""
    by_key = {}
    for mark in marks:
        by_key.setdefault(logos_key(mark["slug"]), mark)

    upgraded = 0
    added = 0

    for key, color in color_marks.items():
        existing = by_key.get(key)
        if existing is not None:
            existing["layers"] = color["layers"]
            existing["colorViewBox"] = color["viewBox"]
            upgraded += 1
            continue

        # A brand Simple Icons does not carry, usually because it was removed on trademark
        # request. Microsoft and Slack are both here. The monochrome fallback is the union of
        # the colour layers, which draws as a solid silhouette.
        #
        # Each layer is reset to the origin first. A path beginning with a lowercase `m` is a
        # *relative* moveto, so plain concatenation would place it relative to wherever the
        # previous layer finished and slide the whole subpath off the canvas. `M0 0` in front
        # makes the relative move measure from the origin, which is what absolute would do,
        # and is a no-op for a layer that already starts absolute.
        union = " ".join(f"M0 0 {layer['path']}" for layer in color["layers"])
        fills = [layer["fill"] for layer in color["layers"] if layer["fill"]]
        marks.append(
            {
                "slug": color["slug"].removesuffix("-icon"),
                "title": color["title"],
                "path": union,
                "viewBox": color["viewBox"],
                "tint": fills[0] if fills else "000000",
                "layers": color["layers"],
                "colorViewBox": color["viewBox"],
            }
        )
        added += 1

    marks.sort(key=lambda mark: mark["slug"])
    return upgraded, added


def main():
    parser = argparse.ArgumentParser(description="Regenerate BrandMarks.json from Simple Icons.")
    parser.add_argument("--version", help="simple-icons npm version, defaults to latest")
    arguments = parser.parse_args()

    version = resolve_version(arguments.version)
    marks, published, missing, unreadable = build(version)

    logos_version, color_marks, undrawable, wrong_shape = build_color_marks()
    upgraded, added = merge_color(marks, color_marks)
    print(
        f"colour: {len(color_marks)} usable of the SVG Logos set "
        f"({undrawable} need gradients or masks, {wrong_shape} are wordmarks); "
        f"{upgraded} brands upgraded, {added} added",
        file=sys.stderr,
    )

    if missing:
        print(f"no SVG in the package: {', '.join(missing)}", file=sys.stderr)
    if unreadable:
        print(f"not a single filled path: {', '.join(unreadable)}", file=sys.stderr)
    if not marks:
        print("no marks produced", file=sys.stderr)
        return 1

    licensed = sum(1 for mark in marks if "license" in mark)
    coloured = sum(1 for mark in marks if "layers" in mark)
    document = {
        "source": "simple-icons + svg-logos",
        "sourceVersion": version,
        "sourceURL": "https://github.com/simple-icons/simple-icons",
        "colorSource": "gilbarbara/logos",
        "colorSourceVersion": logos_version,
        "colorSourceURL": "https://github.com/gilbarbara/logos",
        "generatedBy": "Scripts/generate_marks.py",
        "marks": marks,
    }

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
        handle.write("\n")

    size = os.path.getsize(OUTPUT)
    print(
        f"wrote {len(marks)} marks from {published} published Simple Icons "
        f"({coloured} with colour artwork, {licensed} with licence data) "
        f"to {OUTPUT}, {size} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
