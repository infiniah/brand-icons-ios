# ``BrandIcons``

Resolve a messy service name into ranked brand icon candidates you can act on.

## Overview

Real service names arrive damaged. A bank statement says `NETFLIX.COM`, a receipt says
`Spotify Premium`, a card processor says `SQ *BLUE BOTTLE`. All of them name a brand that has a
logo, and none of them is the brand's name.

```swift
let resolver = BrandIconResolver()
let result = await resolver.resolve("NETFLIX.COM")
let icon = result.best(minimum: 0.8)
```

``BrandIconResolver`` normalises the query, scores it against every brand its providers can see,
and returns ``BrandIconResult`` with candidates sorted best first. Each carries a confidence from
0 to 1, so a caller can decide for itself whether an answer is good enough to apply silently or
ought to go in front of a person.

Providers are consulted cheapest first: marks compiled into the package, then a logo CDN, then
the service's own favicon, then optionally App Store artwork. The resolver stops as soon as a
candidate clears ``ResolverConfiguration/shortCircuitConfidence``, so a brand the bundled
catalogue knows never reaches the network. ``ResolverConfiguration/offline`` removes the network
tiers entirely.

### Deciding what to do with an answer

Two questions, asked separately, because they are not the same question.

```swift
if result.isAmbiguous() {
    present(chooser: result.candidates)
} else if let best = result.best(minimum: 0.8) {
    apply(best)
}
```

``BrandIconResult/best(minimum:)`` asks whether the top candidate is good enough.
``BrandIconResult/isAmbiguous(within:)`` asks whether the runner up is nearly as good, which is
the case that a single best answer cannot express.

## Topics

### Resolving

- ``BrandIconResolver``
- ``ResolverConfiguration``
- ``BrandQuery``

### Reading a result

- ``BrandIconResult``
- ``BrandIconCandidate``
- ``BrandIconSource``
- ``BrandIconShape``
- ``BrandColor``
- ``BrandIconError``

### Drawing

- ``BrandIconView``
- ``BrandVectorShape``
- ``SVGPathParser``

### Providers

- ``BrandIconProvider``
- ``BundledIconProvider``
- ``FaviconProvider``
- ``AppStoreProvider``

### The bundled catalogue

- ``BundledCatalog``
- ``BundledMark``

### Matching

- ``NameNormalizer``
- ``MatchScorer``

### Budgets

- ``RateLimiter``
- ``IconCache``
