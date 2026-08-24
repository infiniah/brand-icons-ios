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
USER_AGENT = "BrandIconsMarkGenerator/1.0"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "Sources", "BrandIcons", "Resources", "BrandMarks.json")

VIEW_BOX = re.compile(r'viewBox="([^"]+)"')
PATH_DATA = re.compile(r'\sd="([^"]+)"')


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


def main():
    parser = argparse.ArgumentParser(description="Regenerate BrandMarks.json from Simple Icons.")
    parser.add_argument("--version", help="simple-icons npm version, defaults to latest")
    arguments = parser.parse_args()

    version = resolve_version(arguments.version)
    marks, published, missing, unreadable = build(version)

    if missing:
        print(f"no SVG in the package: {', '.join(missing)}", file=sys.stderr)
    if unreadable:
        print(f"not a single filled path: {', '.join(unreadable)}", file=sys.stderr)
    if not marks:
        print("no marks produced", file=sys.stderr)
        return 1

    licensed = sum(1 for mark in marks if "license" in mark)
    document = {
        "source": "simple-icons",
        "sourceVersion": version,
        "sourceURL": "https://github.com/simple-icons/simple-icons",
        "generatedBy": "Scripts/generate_marks.py",
        "marks": marks,
    }

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
        handle.write("\n")

    size = os.path.getsize(OUTPUT)
    print(
        f"wrote {len(marks)} of {published} published marks "
        f"({licensed} with licence data) to {OUTPUT}, {size} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
