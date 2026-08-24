# Configuration


```swift
var configuration = ResolverConfiguration.default
configuration.minimumConfidence = 0.5
configuration.maximumCandidates = 3

let resolver = BrandIconResolver(configuration: configuration)
```

| Field | Default | Effect |
| --- | --- | --- |
| `shortCircuitConfidence` | 0.95 | stop asking further providers once a candidate reaches this |
| `minimumConfidence` | 0.35 | candidates below this are discarded rather than returned |
| `maximumCandidates` | 5 | most candidates returned |
| `allowsAppStore` | `false` | whether the App Store tier is in the default stack |
| `allowsNetwork` | `true` | whether any tier that needs the network is in the default stack |
| `requestsPerMinute` | 15 | carried for a provider stack that applies it, see below |
| `excludesRestrictiveLicenses` | `false` | drop marks whose recorded terms forbid commercial use or derivative works |

```swift
let resolver = BrandIconResolver(
    providers: [
        BundledIconProvider(),
        FaviconProvider()
    ]
)
```

Passing `providers:` replaces the default stack entirely. `allowsNetwork` and `allowsAppStore`
gate only the stack the resolver builds for itself, so when you supply your own array those two
fields stop gating anything and the array you passed is what runs.

`RateLimiter` and `IconCache` are standalone actors you compose in yourself. `BrandIconResolver`
does not throttle or cache payloads on your behalf:

```swift
let limiter = RateLimiter(requestsPerMinute: 15)
await limiter.acquire()
let candidates = try await provider.candidates(for: query)
```

## Confidence and ambiguity

Two calls, and the difference between them is the whole design.

```swift
let result = await resolver.resolve("Amazon Prime")

result.best(minimum: 0.8)   // the top candidate, only if it clears the bar
result.isAmbiguous()        // true when the runner up is nearly as good
```

`best(minimum:)` returns the top candidate only when it clears the bar you set, and nil
otherwise. Set the bar from what a wrong answer costs you. A list that can fall back to a
letter tile is happy at the 0.5 default. A flow that writes the choice into a database should
stay near 0.8 and put anything below it in front of a person.

`isAmbiguous(within:)` asks a different question: not whether the best candidate is good, but
whether the second one is nearly as good. `Amazon Prime` scores 0.81 against a mark titled
`Amazon` and 0.84 against one titled `Amazon Prime Video`. Both readings are defensible, the
gap is 0.03, and picking silently would be guessing on your behalf. Show a chooser instead:

```swift
if result.isAmbiguous() {
    present(chooser: result.candidates)
} else if let best = result.best(minimum: 0.8) {
    apply(best)
} else {
    keepTheLetterTile()
}
```
