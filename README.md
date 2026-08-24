# BrandIcons

[![CI](https://github.com/infiniah/brand-icons-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/infiniah/brand-icons-ios/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS_%7C_macOS_%7C_watchOS_%7C_tvOS_%7C_visionOS-yellowgreen?style=flat-square)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-orange?style=flat-square)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-black?style=flat-square)](LICENSE)

**Turn a messy service name into a brand icon, with a confidence score you can act on.**

`NETFLIX.COM`, `APPLE.COM/BILL SPOTIFY` and `SQ *BLUE BOTTLE` are what a bank statement actually
looks like. BrandIcons resolves names like those to ranked candidates, offline, in microseconds.

```swift
let resolver = BrandIconResolver()
let result = await resolver.resolve("APPLE.COM/BILL SPOTIFY")

result.best(minimum: 0.8)   // Spotify, 0.90
```

## Features

- **3,453 marks compiled in.** No network, no CDN, no rate limit, no key.
- **A score you can act on.** Built from token overlap and structure, not one fuzzy distance, so
  you can set a threshold and know what it means.
- **Says when it isn't sure.** `isAmbiguous()` is the signal to show a chooser instead of guessing.
- **Optional network tiers.** The App Store and a site's own favicon, off by default.
- **Fast.** 4.6 µs per lookup after the catalogue loads.
- **Swift 6, strict concurrency**, zero dependencies.

## Installation

```swift
.package(url: "https://github.com/infiniah/brand-icons-ios", from: "1.0.0")
```

## Usage

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

When `candidate` is nil the view draws a monogram, so a list never develops holes while lookups
are in flight.

## Acting on the score

The number answers *is this the right brand*, so pick a threshold from what a wrong answer costs.

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

See [docs/matching.md](docs/matching.md) for how the score is built.

## Offline by default

The bundled catalogue answers first and the resolver stops as soon as a candidate is good enough,
so a name it knows never opens a socket. To guarantee that:

```swift
let resolver = BrandIconResolver(configuration: .offline)
```

The network tiers exist for what a monochrome catalogue cannot serve. See
[docs/providers.md](docs/providers.md).

## Documentation

| | |
| --- | --- |
| [Provider tiers](docs/providers.md) | what each source costs, and when a bundled mark is the wrong picture |
| [Configuration](docs/configuration.md) | every option, and ranking by preferred source |
| [How matching works](docs/matching.md) | the scoring bands, lookup cost, and measuring against your own names |
| [Licensing the marks](docs/licensing.md) | CC0, trademark, and the thirteen restrictive marks |

API reference: build the DocC catalogue with `swift package generate-documentation`.

## Example app

`Examples/Applied` is a job application tracker that resolves an icon for every company and shows
what each tier returned, ranked, with the time each took. Open `Applied.xcodeproj` and run.

## Contributing

Issues and pull requests welcome. Run `swift test` before opening one.

## License

MIT for the code. The marks carry their own terms, see [docs/licensing.md](docs/licensing.md)
and [NOTICE](NOTICE).
