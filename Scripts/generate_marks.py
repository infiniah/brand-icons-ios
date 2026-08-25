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
import math
import json
import os
import re
import sys
import tarfile
import urllib.request

REGISTRY = "https://registry.npmjs.org/simple-icons"
LOGOS_REGISTRY = "https://registry.npmjs.org/@iconify-json/logos"
THESVG_REGISTRY = "https://registry.npmjs.org/@iconify-json/thesvg-color"

# Simple Icons is monochrome by design: one path, one colour. That is the right call for a
# uniform set and the wrong picture for a brand whose identity *is* colour, where the mark
# comes out a flat silhouette or, as with Figma, a hollow outline.
#
# gilbarbara's SVG Logos is CC0 as well and carries the real multi colour artwork, plus a few
# hundred brands Simple Icons has removed on trademark request. Marks from it are attached to
# the matching Simple Icons entry as `layers`, so the catalogue keeps one row per brand.
#
# Only the marks this package can actually draw are taken: a gradient, a mask or a clip path
# needs a renderer this does not have.
#
# The aspect cap keeps a long wordmark out of an icon slot. It is not the mechanism that prefers
# an icon over a wordmark, though: `harvest` already picks the squarest variant a brand ships. So
# the cap's only effect is on brands that ship nothing else, where the choice is a wide mark or no
# mark at all. Disney, Hulu and Prime Video are all wordmark only, and absent served nobody.
LOGOS_MAX_ASPECT = 3.5
USER_AGENT = "BrandIconsMarkGenerator/1.0"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "Sources", "BrandIcons", "Resources", "BrandMarks.json")
COMPACT_OUTPUT = os.path.join(ROOT, "Sources", "BrandIcons", "Resources", "BrandMarksCompact.json")

# Coordinates are trimmed to this many decimals. Every mark is drawn inside a viewBox of 24 to 512
# units, so the third decimal is far below a pixel at any size an icon is shown, and it costs real
# bytes in every app that ships the catalogue.
COORDINATE_PLACES = 2

# A mark whose path data is larger than this is an illustration rather than an icon: it will be
# mush at 40 points and it is what makes the catalogue heavy. The compact catalogue leaves them out.
COMPACT_MAX_PATH_BYTES = 4 * 1024

# SVG lets a number omit its leading zero and lets numbers run together, so `.0741.0741` is two
# of them. A naive `\d+\.\d+` matches `0741.0741` straight across the boundary and rewrites two
# coordinates as one, off by a factor of ten. This follows the grammar instead.
SVG_NUMBER = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")

VIEW_BOX = re.compile(r'viewBox="([^"]+)"')
PATH_DATA = re.compile(r'\sd="([^"]+)"')
LOGOS_ELEMENT = re.compile(r"<([a-zA-Z]+)")
LOGOS_PATH = re.compile(r"<path([^>]*?)/?>")
LOGOS_D = re.compile(r'\sd="([^"]+)"')
LOGOS_FILL = re.compile(r'fill="(#[0-9A-Fa-f]{3,8})"')
LOGOS_UNDRAWABLE = (
    "url(#", "<defs", "clipPath", "<mask", "stroke=", "<image", "<text", "transform=",
)


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


def download_iconify(registry, name):
    """One Iconify published icon set."""
    with urllib.request.urlopen(request(f"{registry}/latest"), timeout=60) as response:
        version = json.load(response)["version"]
    url = f"{registry}/-/{name}-{version}.tgz"
    print(f"fetching {url}", file=sys.stderr)
    with urllib.request.urlopen(request(url), timeout=300) as response:
        payload = response.read()
    archive = tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz")
    icons = json.loads(read_member(archive, "package/icons.json"))
    archive.close()
    return version, icons


def color_layers(body):
    """The fill coloured paths of one icon, or None when it needs a renderer we do not have.

    A bare `<g>` is allowed through because both sets use one purely as a wrapper and every path
    inside carries its own fill. A `transform` is not: applying an arbitrary matrix is a renderer
    feature this package does not have, and ignoring one silently misplaces the artwork.
    """
    if not set(LOGOS_ELEMENT.findall(body)) <= {"path", "g"}:
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
        layer = {"path": path.group(1).strip(),
                 "fill": fill.group(1).lstrip("#").upper() if fill else None}
        if 'fill-rule="evenodd"' in attributes:
            layer["evenOdd"] = True
        layers.append(layer)
    return layers or None


NUMBER = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
COMMAND = re.compile(r"[MmZzLlHhVvCcSsQqTtAa]")
ARITY = {"m": 2, "l": 2, "h": 1, "v": 1, "c": 6, "s": 4, "q": 4, "t": 2, "a": 7, "z": 0}


def arc_centre(start_x, start_y, end_x, end_y, rx, ry, degrees, large_arc, sweep):
    """The centre and corrected radii of an SVG arc, following the SVG 1.1 notes (F.6.5).

    Returns None for a degenerate arc, which the caller treats as a straight line.
    """
    rx, ry = abs(rx), abs(ry)
    if rx == 0 or ry == 0 or (start_x == end_x and start_y == end_y):
        return None

    phi = math.radians(degrees)
    cos_phi, sin_phi = math.cos(phi), math.sin(phi)
    dx, dy = (start_x - end_x) / 2, (start_y - end_y) / 2
    x1 = cos_phi * dx + sin_phi * dy
    y1 = -sin_phi * dx + cos_phi * dy

    lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lam > 1:
        correction = math.sqrt(lam)
        rx *= correction
        ry *= correction

    denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
    if denominator <= 0:
        return None
    numerator = max(0.0, rx * rx * ry * ry - denominator)
    coefficient = (-1 if bool(large_arc) == bool(sweep) else 1) * math.sqrt(numerator / denominator)

    cx1 = coefficient * rx * y1 / ry
    cy1 = -coefficient * ry * x1 / rx
    centre_x = cos_phi * cx1 - sin_phi * cy1 + (start_x + end_x) / 2
    centre_y = sin_phi * cx1 + cos_phi * cy1 + (start_y + end_y) / 2

    start_angle = math.atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
    end_angle = math.atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx)
    sweep_angle = end_angle - start_angle
    if sweep and sweep_angle < 0:
        sweep_angle += 2 * math.pi
    elif not sweep and sweep_angle > 0:
        sweep_angle -= 2 * math.pi

    return centre_x, centre_y, rx, ry, phi, start_angle, sweep_angle


def arc_points(start_x, start_y, end_x, end_y, rx, ry, degrees, large_arc, sweep, steps=48):
    """Points along an SVG arc, or None when it is degenerate.

    Bounding an arc by its centre plus radius bounds the whole ellipse, and a shallow arc off a
    large radius then measures hundreds of units outside a canvas it never leaves. Walking the
    swept angle costs nothing at build time and is the difference between keeping a mark and
    dropping it.
    """
    geometry = arc_centre(start_x, start_y, end_x, end_y, rx, ry, degrees, large_arc, sweep)
    if geometry is None:
        return None

    centre_x, centre_y, rx, ry, phi, start_angle, sweep_angle = geometry
    cos_phi, sin_phi = math.cos(phi), math.sin(phi)

    points = []
    for step in range(steps + 1):
        angle = start_angle + sweep_angle * step / steps
        x = rx * math.cos(angle)
        y = ry * math.sin(angle)
        points.append((
            centre_x + cos_phi * x - sin_phi * y,
            centre_y + sin_phi * x + cos_phi * y,
        ))
    return points


def bezier_extremes(p0, p1, p2, p3=None):
    """Where a Bezier actually reaches on one axis, control points excluded.

    A curve is contained by its control points but rarely touches them, so bounding it by the
    hull calls artwork out of bounds that draws perfectly inside the canvas. The real extremes
    are the endpoints plus whichever roots of the derivative fall inside the span.
    """
    points = [p0, p3 if p3 is not None else p2]
    if p3 is None:
        denominator = p0 - 2 * p1 + p2
        if abs(denominator) > 1e-12:
            t = (p0 - p1) / denominator
            if 0 < t < 1:
                u = 1 - t
                points.append(u * u * p0 + 2 * u * t * p1 + t * t * p2)
        return points

    a = -p0 + 3 * p1 - 3 * p2 + p3
    b = 2 * (p0 - 2 * p1 + p2)
    c = p1 - p0

    roots = []
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            roots.append(-c / b)
    else:
        discriminant = b * b - 4 * a * c
        if discriminant >= 0:
            root = math.sqrt(discriminant)
            roots.extend(((-b + root) / (2 * a), (-b - root) / (2 * a)))

    for t in roots:
        if 0 < t < 1:
            u = 1 - t
            points.append(
                u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
            )
    return points


def path_extent(data):
    """The box the path actually draws in, or None when it cannot be walked.

    Curves are measured, not bounded by their control points: the job is to reject artwork whose
    geometry plainly does not belong to the viewBox the set declares, and a hull bound rejects
    good marks whose control points sit outside a curve that stays in.
    """
    tokens = re.findall(f"{COMMAND.pattern}|{NUMBER.pattern}", data)
    index = 0
    command = None
    x = y = start_x = start_y = 0.0
    control_x = control_y = None
    last_kind = None
    lo_x = lo_y = float("inf")
    hi_x = hi_y = float("-inf")

    def see(px, py):
        nonlocal lo_x, lo_y, hi_x, hi_y
        lo_x, lo_y = min(lo_x, px), min(lo_y, py)
        hi_x, hi_y = max(hi_x, px), max(hi_y, py)

    def see_all(xs, ys):
        for px in xs:
            for py in ys:
                see(px, py)

    while index < len(tokens):
        token = tokens[index]
        if COMMAND.fullmatch(token):
            command = token
            index += 1
        if command is None:
            return None
        kind = command.lower()
        relative = command.islower()
        count = ARITY[kind]
        operands = tokens[index:index + count]
        if len(operands) < count:
            return None
        index += count
        try:
            values = [float(value) for value in operands]
        except ValueError:
            return None

        base_x, base_y = (x, y) if relative else (0.0, 0.0)

        if kind == "z":
            x, y = start_x, start_y
            see(x, y)
        elif kind == "h":
            x = base_x + values[0]
            see(x, y)
        elif kind == "v":
            y = base_y + values[0]
            see(x, y)
        elif kind in ("m", "l"):
            see(x, y)
            x, y = base_x + values[0], base_y + values[1]
            see(x, y)
            if kind == "m":
                start_x, start_y = x, y
                command = "l" if relative else "L"
        elif kind in ("c", "s"):
            if kind == "c":
                c1x, c1y = base_x + values[0], base_y + values[1]
                c2x, c2y = base_x + values[2], base_y + values[3]
                end_x, end_y = base_x + values[4], base_y + values[5]
            else:
                # A smooth curve reflects the previous control point through the current one.
                if last_kind in ("c", "s") and control_x is not None:
                    c1x, c1y = 2 * x - control_x, 2 * y - control_y
                else:
                    c1x, c1y = x, y
                c2x, c2y = base_x + values[0], base_y + values[1]
                end_x, end_y = base_x + values[2], base_y + values[3]
            see_all(bezier_extremes(x, c1x, c2x, end_x), bezier_extremes(y, c1y, c2y, end_y))
            control_x, control_y = c2x, c2y
            x, y = end_x, end_y
        elif kind in ("q", "t"):
            if kind == "q":
                cx, cy = base_x + values[0], base_y + values[1]
                end_x, end_y = base_x + values[2], base_y + values[3]
            else:
                if last_kind in ("q", "t") and control_x is not None:
                    cx, cy = 2 * x - control_x, 2 * y - control_y
                else:
                    cx, cy = x, y
                end_x, end_y = base_x + values[0], base_y + values[1]
            see_all(bezier_extremes(x, cx, end_x), bezier_extremes(y, cy, end_y))
            control_x, control_y = cx, cy
            x, y = end_x, end_y
        elif kind == "a":
            end_x = base_x + values[5]
            end_y = base_y + values[6]
            points = arc_points(x, y, end_x, end_y, values[0], values[1],
                                values[2], values[3], values[4])
            if points is None:
                see(end_x, end_y)
            else:
                for point_x, point_y in points:
                    see(point_x, point_y)
            x, y = end_x, end_y
            see(x, y)
        else:
            return None

        if kind not in ("c", "s", "q", "t"):
            control_x = control_y = None
        last_kind = kind

    if lo_x > hi_x:
        return None
    return lo_x, lo_y, hi_x, hi_y


def fits(layers, width, height):
    """True when every layer's geometry sits inside the declared canvas, give or take a twentieth.

    Iconify carries marks whose stated width is a fraction of the geometry inside them, and drawn
    against that box they land off the canvas. The twentieth is headroom for the difference
    between the sampled arcs measured here and the curves a port converts them into.
    """
    margin_x = max(1.0, width * 0.05)
    margin_y = max(1.0, height * 0.05)
    for layer in layers:
        extent = path_extent(layer["path"])
        if extent is None:
            return False
        lo_x, lo_y, hi_x, hi_y = extent
        if lo_x < -margin_x or lo_y < -margin_y:
            return False
        if hi_x > width + margin_x or hi_y > height + margin_y:
            return False
    return True


def logos_key(slug):
    """`spotify-icon`, `duolingo-2024` and `spotify` all reduce to the brand Simple Icons names.

    The year suffix matters: theSVG ships `duolingo` and `duolingo-2024` side by side, the second
    being the current artwork. Without folding them together they compete as separate brands and
    a search for Duolingo finds the older drawing.
    """
    base = slug.removesuffix("-icon")
    base = re.sub(r"-(19|20)\d{2}$", "", base)
    return base.replace("-", "").replace(".", "").lower()


def logos_title(slug):
    """A readable name from a slug, used only when Simple Icons has no entry to borrow from.

    The set ships no titles, so this is a guess. It only has to be good enough to score
    against, since matching normalises both sides anyway.
    """
    base = re.sub(r"-(19|20)\d{2}$", "", slug.removesuffix("-icon"))
    return " ".join(part.capitalize() for part in base.split("-"))


def harvest(icons):
    """Every drawable, icon shaped mark in one Iconify set, best variant per brand."""
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

        layers = color_layers(icon["body"])
        if layers is None:
            skipped_undrawable += 1
            continue
        if not fits(layers, width, height):
            skipped_shape += 1
            continue

        key = logos_key(slug)
        candidate = {
            "slug": slug,
            "title": logos_title(slug),
            "viewBox": [0.0, 0.0, float(width), float(height)],
            "layers": layers,
        }

        def squareness(entry):
            _, _, w, h = entry["viewBox"]
            return max(w, h) / min(w, h)

        previous = chosen.get(key)
        # `spotify-icon` is the square mark and `spotify` is the wordmark, so when both survive
        # the aspect filter the squarer one is the icon. A dated variant such as `duolingo-2024`
        # is the newer drawing of the same brand, so it wins ties.
        if previous is None or squareness(candidate) < squareness(previous) or (
            squareness(candidate) == squareness(previous) and slug > previous["slug"]
        ):
            chosen[key] = candidate

    return chosen, skipped_undrawable, skipped_shape


def build_color_marks():
    """Colour marks from both sets, keyed the way Simple Icons slugs normalise.

    theSVG Color is asked first because it is five times the size and carries current artwork,
    Duolingo's 2024 owl among it. SVG Logos fills what it misses.
    """
    thesvg_version, thesvg_icons = download_iconify(THESVG_REGISTRY, "thesvg-color")
    logos_version, logos_icons = download_iconify(LOGOS_REGISTRY, "logos")

    primary, primary_undrawable, primary_shape = harvest(thesvg_icons)
    secondary, secondary_undrawable, secondary_shape = harvest(logos_icons)

    merged = dict(secondary)
    merged.update(primary)

    versions = {"thesvg-color": thesvg_version, "logos": logos_version}
    skipped = (primary_undrawable + secondary_undrawable, primary_shape + secondary_shape)
    return versions, merged, skipped[0], skipped[1]


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


def trim_precision(path_data, places=COORDINATE_PLACES):
    """Rounds every coordinate, dropping digits no icon size can express.

    Integers are returned untouched. An arc's two flags may be written `00` with no separator, and
    reformatting that as a single number would delete one of them.
    """
    def shorten(match):
        token = match.group(0)
        if "." not in token:
            return token
        text = f"{float(token):.{places}f}"
        whole, _, fraction = text.partition(".")
        fraction = fraction.rstrip("0")
        return f"{whole}.{fraction}" if fraction else whole

    return SVG_NUMBER.sub(shorten, path_data)


def trim_verified(path_data):
    """Trims a path, and keeps the original when the trim would move the drawing.

    The rewrite is textual and the grammar is full of traps, so every path is parsed before and
    after and the result compared. A mark that does not survive keeps its full precision rather
    than being shipped subtly wrong.
    """
    trimmed = trim_precision(path_data)
    before = path_extent(path_data)
    after = path_extent(trimmed)
    if before is None or after is None:
        return path_data
    if max(abs(a - b) for a, b in zip(before, after)) > 0.05:
        return path_data
    return trimmed


def slim(mark):
    """Drops the monochrome path a colour mark never draws.

    A mark with `layers` is always drawn from them, so carrying the flattened silhouette as well
    was three megabytes of geometry nothing rendered. Marks without colour keep their path, which
    is the only thing they have.

    Coordinates are deliberately left at full precision. Rounding them saves about a tenth of the
    compressed size and rewrites path data textually, in a grammar where `.0741.0741` is two
    numbers rather than one. That trade is not worth a silently misplaced coordinate.
    """
    mark = dict(mark)
    if mark.get("layers"):
        mark.pop("path", None)
    return mark


def path_bytes(mark):
    total = len(mark.get("path", "").encode("utf-8"))
    return total + sum(len(layer["path"].encode("utf-8")) for layer in mark.get("layers", []))


def main():
    parser = argparse.ArgumentParser(description="Regenerate BrandMarks.json from Simple Icons.")
    parser.add_argument("--version", help="simple-icons npm version, defaults to latest")
    arguments = parser.parse_args()

    version = resolve_version(arguments.version)
    marks, published, missing, unreadable = build(version)

    color_versions, color_marks, undrawable, wrong_shape = build_color_marks()
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

    marks = [slim(mark) for mark in marks]
    compact = [mark for mark in marks if path_bytes(mark) <= COMPACT_MAX_PATH_BYTES]

    licensed = sum(1 for mark in marks if "license" in mark)
    coloured = sum(1 for mark in marks if "layers" in mark)
    document = {
        "source": "simple-icons + thesvg-color + svg-logos",
        "sourceVersion": version,
        "sourceURL": "https://github.com/simple-icons/simple-icons",
        "colorSource": "thesvg-color + svg-logos",
        "colorSourceVersion": color_versions,
        "colorSourceURL": "https://thesvg.org",
        "generatedBy": "Scripts/generate_marks.py",
        "marks": marks,
    }

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
        handle.write("\n")

    with open(COMPACT_OUTPUT, "w", encoding="utf-8") as handle:
        json.dump({**document, "marks": compact}, handle,
                  ensure_ascii=False, separators=(",", ":"), sort_keys=False)
        handle.write("\n")

    print(
        f"compact catalogue: {len(compact)} marks, {len(marks) - len(compact)} left out for being "
        f"larger than {COMPACT_MAX_PATH_BYTES // 1024} KB of path data, "
        f"{os.path.getsize(COMPACT_OUTPUT)} bytes",
        file=sys.stderr,
    )

    size = os.path.getsize(OUTPUT)
    print(
        f"wrote {len(marks)} marks from {published} published Simple Icons "
        f"({coloured} with colour artwork, {licensed} with licence data) "
        f"to {OUTPUT}, {size} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
