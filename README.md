# BrandIcons

[![CI](https://github.com/infiniah/brand-icons-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/infiniah/brand-icons-ios/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS_%7C_macOS_%7C_watchOS_%7C_tvOS_%7C_visionOS-yellowgreen?style=flat-square)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-orange?style=flat-square)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-black?style=flat-square)](LICENSE)

**You have a messy string. You need the right brand icon. That is the whole problem.**

```
"APPLE.COM/BILL SPOTIFY"   →   Spotify      0.90
"SQ *BLUE BOTTLE"          →   nothing      —
"NOTION LABS INC"          →   Notion       0.81
"Apple One"                →   ambiguous, ask the user
```

Those are real bank statement descriptors. Exact matching finds none of them. A `Dictionary`
lookup keyed on the name finds none of them. This library resolves them offline, in microseconds,
and tells you how sure it is so you can decide what to do about it.

<p align="center">
  <img src="docs/images/applied-ios.png" width="260" alt="The example app resolving six companies to their real marks">
  <img src="docs/images/applied-ios-dark.png" width="260" alt="The same list in dark mode">
  <img src="docs/images/applied-ios-sheet.png" width="260" alt="Adding an application, with every tier's answer ranked">
</p>

## Why not just…

**…ship an icon set and look up by name?** An icon set gives you files. It does not answer "which
brand is `APPLE.COM/BILL SPOTIFY`", which is the actual work. You would end up writing the
normaliser, the scorer and the tie-breaking yourself, which is what this is.

**…call a logo API?** It costs money per lookup, needs a key, breaks when it is down, and tells a
third party every company name your users type. This runs offline with nothing compiled in but a
JSON file.

**…use the App Store search?** You can, and this wraps it as an optional tier. But it is rate
limited to about twenty requests a minute, it needs a network, and Apple's terms describe that
artwork as promotional material for store content. It is off by default for those reasons.

**…just take the top match?** That is how you silently draw the wrong logo. `Apple One` matches
`Apple`, `Apple TV` and `Apple Music` almost equally well, and the honest answer is to ask. The
score exists so you can tell those cases apart.

## What you get

- **4,309 marks compiled in**, 3,175 of them in full colour. No network, no key, no rate limit.
- **A score you can act on**, built from token overlap and structure rather than one fuzzy distance.
- **`isAmbiguous()`**, so a coin-flip becomes a chooser instead of a wrong icon.
- **Optional network tiers**: Apple's App Store, and the site's own favicon.
- 4.6 µs per lookup once the catalogue is loaded.
- Swift 6, strict concurrency, zero dependencies.

## Install

```swift
.package(url: "https://github.com/infiniah/brand-icons-ios", from: "1.0.0")
```

## Use

```swift
import BrandIcons

let resolver = BrandIconResolver()

for application in applications {
    let query = BrandQuery(name: application.company, domain: application.domain)
    application.icon = await resolver.resolve(query).best()
}
```

`BrandIconResolver` is an actor and caches per query, so calling it once per row of a list is fine.

To draw the answer:

```swift
BrandIconView(candidate: icon, fallbackText: application.company, size: 40)
```

When `candidate` is nil it draws a monogram, so a list never develops holes while lookups are in
flight.

## Acting on the score

Pick a threshold from what a wrong answer costs you.

```swift
let result = await resolver.resolve("Apple One")

if let best = result.best(minimum: 0.8) {
    draw(best)                        // confident enough to write down
} else if result.isAmbiguous() {
    askTheUser(result.candidates)     // Apple, Apple Music and Apple TV all score alike
}
```

| Score | Meaning |
| --- | --- |
| 1.00 | the normalised names are identical |
| 0.72 – 0.90 | the query is the brand plus extra words, like a statement descriptor |
| 0.42 – 0.60 | the brand is more specific than the query. `Apple` is not `Apple TV` |
| below 0.35 | discarded rather than returned |

## Offline by default

The bundled catalogue answers first and the resolver stops as soon as a candidate is good enough,
so a name it knows never opens a socket. To guarantee it:

```swift
let resolver = BrandIconResolver(configuration: .offline)
```

## Other platforms

The same library, scored against the same fixtures so all of them agree on what a name means.

| Platform | Repository |
| --- | --- |
| iOS and macOS, Swift | this repository |
| Android, Kotlin | [infiniah/brand-icons-android](https://github.com/infiniah/brand-icons-android) |
| Flutter, Dart | [infiniah/brand-icons-flutter](https://github.com/infiniah/brand-icons-flutter) |
| React Native and Expo, TypeScript | [infiniah/brand-icons-react-native](https://github.com/infiniah/brand-icons-react-native) |

## Documentation

| | |
| --- | --- |
| [Provider tiers](docs/providers.md) | what each source costs, and when a bundled mark is the wrong picture |
| [Configuration](docs/configuration.md) | every option, and ranking by preferred source |
| [How matching works](docs/matching.md) | the scoring bands, lookup cost, and measuring against your own names |
| [Licensing the marks](docs/licensing.md) | CC0, MIT, trademark, and the restrictive handful |

## Example app

`Examples/Applied` is a job application tracker that resolves an icon for every company and shows
what each tier returned, ranked, with the time each took. Open `Applied.xcodeproj` and run.

## Contributing

Issues and pull requests welcome. Run `swift test` before opening one.

## License

MIT for the code. The marks carry their own terms, see [docs/licensing.md](docs/licensing.md)
and [NOTICE](NOTICE).
