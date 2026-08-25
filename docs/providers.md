# Provider tiers

How each source is asked, what it costs, and what it is allowed to claim.


Providers are consulted cheapest first, and the resolver stops as soon as a candidate clears
`shortCircuitConfidence`, so a name the bundled catalogue matches outright never opens a socket.

| Tier | `BrandIconSource` | Network per lookup | Credential | Payload | Confidence it can reach |
| --- | --- | --- | --- | --- | --- |
| Bundled marks | `.bundled` | none | none | vector | up to 1.00 |
| Favicon | `.favicon` | manifest, then head, then guessed paths | none | raster | 0.35 to 0.65 |
| App Store | `.appStore` | 1 request, plus 1 for artwork if it was not remembered | none | raster | up to 1.00 |

**Bundled marks** are 4,770 paths compiled into the package, 4,595 of them full colour,
generated from Simple Icons 16.28.0, theSVG Color and SVG Logos by `Scripts/generate_marks.py`. They need no network, cannot
be rate limited, and carry the brand's own colour, which is why they are asked first. The whole
set is 4.70 MB of JSON, 1.92 MB gzipped, and it decodes on first lookup rather than at launch.
See [Lookup cost](matching.md#lookup-cost) for what that costs.

**Favicon** reads the service's own site, in the order a site is most likely to be truthful and
largest usable icon first: the Web App Manifest at `/site.webmanifest` or `/manifest.json`, whose
`icons` array is where a modern site puts its 192 and 512 pixel marks; then the document head,
whose `apple-touch-icon` and `icon` link tags are the only place a hashed or CDN icon path exists
and whose `manifest` tag points at a manifest on a path nobody would guess; then
`/apple-touch-icon.png` and `/favicon.ico`, guessed, and last because they usually are not there
and `favicon.ico` is usually 16 or 32 pixels. No third party sits in the middle and nothing needs
a key, which also means no icon service learns every domain your users look up.

Its confidence carries two separate uncertainties. Whether this is the right brand at all caps
the tier at `FaviconProvider.ceiling`, 0.65, well under a real vector mark: a site answering on a
host proves the host exists, not that it belongs to the company the user meant, and a domain
guessed from a statement descriptor often does not. Whether the icon is usable then scales within
that range, from the pixel size measured in the bytes that arrived rather than the size the site
declared, on a log curve because the useful spread is 128 to 512 rather than 16 to 512. A 16
pixel `.ico` drawn at 44 points is four pixels per point of blur on a 3x screen, and reporting it
as confidently as a 512 pixel manifest icon told the caller nothing.

**App Store** is off by default. Apple limits the iTunes Search API to roughly twenty requests a
minute per client and answers 429 beyond that, and Apple's terms describe App Store artwork as
promotional material for store content, to be shown near a store badge that links to the store.
Whether labelling a row of your own interface with an app icon fits that description is a
question about your app, not about this package, so the switch is yours to throw:

```swift
var configuration = ResolverConfiguration.default
configuration.allowsAppStore = true

let resolver = BrandIconResolver(configuration: configuration)
```

## Running offline

```swift
let resolver = BrandIconResolver(configuration: .offline)
```

`.offline` builds a stack of bundled marks only. Nothing in that path opens a URL session, so
lookups need no network, no credential and no third party. Every result comes back as `.vector`,
which scales to any size and tints to the brand colour without a download.

The same thing spelled out, if you would rather be explicit:

```swift
let resolver = BrandIconResolver(providers: [BundledIconProvider()])
```

`BundledIconProvider` also takes its marks as an argument, so you can ship your own catalogue
alongside the generated one:

```swift
BundledIconProvider(marks: BundledCatalog.all + myOwnMarks)
```

## When the bundled mark is the wrong picture

The bundled catalogue is [Simple Icons](https://simpleicons.org), which is a **monochrome, single
path** set by design. Every mark is one shape and one tint.

For most brands that is the logo. Spotify, Netflix, Dropbox and Notion really are silhouettes, so
the bundled mark is indistinguishable from the real thing.

For a brand whose identity *is* colour, it is not. Figma is five coloured shapes and Duolingo is a
full colour owl; flattened to one path they become white outlines. Both still score `1.00`, because
confidence answers "is this the right brand" and says nothing about whether the artwork looks like
what people recognise. Those two questions come apart, and no scoring change will fix it, because
the information was never in the file.

If that matters for your app, prefer a source that returns real artwork:

```swift
var configuration = ResolverConfiguration.default
configuration.allowsAppStore = true
```

```swift
configuration.preferredSources = []                          // rank on confidence alone
```

Preference is gated on `preferenceThreshold`, which defaults to `0.8`. Without a bar it would be
actively harmful: the favicon tier answers for a domain guessed from the name, so `Acme Corp`
cheerfully returns whatever `acmecorp.com` happens to serve, and letting that outrank a certain
catalogue match trades a dull icon for a wrong one.

So at the default, App Store artwork for a name it matched exactly wins, and a favicon scraped off a
guessed domain does not. A favicon *does* win once you pass a real `domain`, because then it is the
brand's own declared icon and nothing beats that.

### What this does not fix

With the App Store tier off, which is the default, `Figma` still draws as the outline. No ranking
change can fix that, because the only mark available offline is the flattened one. If brand fidelity
matters more to you than staying offline, turn a network tier on. If it does not, the bundled mark is
still the right brand, and `BrandIconResult.isAmbiguous` will tell you when even that is a guess.

Read the App Store terms note under [Provider tiers](providers.md) before enabling it.

## Why there is no Google Play tier

Apple publishes the iTunes Search API: no key, documented, and reachable from anywhere, which is
why this package can ask it for artwork on Android as readily as on iOS. The icon it returns is
the iOS one, and for almost every brand that is the same drawing as the Play listing.

Google publishes no equivalent. The Play Developer API manages apps you already own, and the
Play EMM API's app search is gated behind enterprise mobility enrolment. Neither is a public
lookup. What is left is scraping the store's web pages, which the terms forbid and which breaks
whenever the markup changes, so this package does not do it and will not gain a `.googlePlay`
source until Google ships something to point it at.

The tier is therefore named for Apple in the UI on both platforms, because "App Store" beside a
Play Store button reads like a mistake.
