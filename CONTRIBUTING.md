# Contributing

## Getting set up

```sh
swift build
swift test
```

The package targets iOS 17, macOS 14, watchOS 10, tvOS 17 and visionOS 1, builds in Swift 6
language mode, and has no dependencies. `swift build` covers macOS. If you touch anything under
`Sources/BrandIcons/UI`, build for iOS too, since that code is behind `#if canImport(SwiftUI)`
and parts of it are gated on UIKit:

```sh
xcodebuild build -scheme BrandIcons -destination 'generic/platform=iOS'
```

The example app lives in `Examples/Applied`. It depends on the package by relative path, so
changes show up with no resolution step:

```sh
xcodebuild build -project Examples/Applied/Applied.xcodeproj \
  -scheme Applied -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

CI runs the same three commands on `macos-26`. See `.github/workflows/ci.yml`.

## What a good change looks like

**Adding a brand mark.** Marks are generated, not hand written. `Scripts/generate_marks.py`
builds `Sources/BrandIcons/Resources/BrandMarks.json` from a Simple Icons release, taking
every icon that release ships. There is nothing to add by hand: regenerate against a newer
release and the new brand arrives with it. Do not hand edit the JSON. Regenerating can also
drop marks, because brands can ask Simple Icons to remove their icon, so read what the script
reports about icons it skipped.

**Adding a provider.** Conform to `BrandIconProvider` and add a case to `BrandIconSource`.
Return an empty array for "no match" rather than throwing, and reserve throwing for something
the caller can act on, such as `BrandIconError.rateLimited(retryAfter:)`. Give the tier a
confidence ceiling it deserves: a source that proves a host answered is not as trustworthy as
one that proves a brand owns a mark, and scoring it as though it were will quietly outrank
better answers. If the provider carries terms or a rate limit, document them on the provider so
the person turning it on reads them.

**Changing the matcher.** `MatchScorer` is the part most likely to regress silently, because a
change that fixes one brand usually breaks another. Bring a test with the real input string that
motivated the change, statement noise and all, and say in the pull request which queries move
and by how much.

**Changing a public API.** Doc comments are the API here, so update them in the same commit. Say
what the type is for and what a caller should do with it, not what the code plainly does.

## House style

- One public type per file, named after it. No grouping files.
- Doc comments (`///`) are wanted. Ordinary comments are not: if code needs one to be read
  correctly, prefer a clearer name or a smaller function. The exception is a workaround for a
  framework bug, which needs a link.
- No em dashes or en dashes anywhere a reader sees them, including doc comments.
- Every view gets previews covering light and dark and each state it can be in.

## Before opening a pull request

Run `swift test`, build the example app, and describe the change in terms of what a caller sees
rather than what the diff does.
