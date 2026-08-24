# How matching works

What the confidence number is built from, what a lookup costs, and how to measure the
tiers against names you actually have.


`NameNormalizer` lowercases, folds diacritics, collapses punctuation, and drops two kinds of
word: card processor noise (`com`, `inc`, `ltd`, `recurring`) and tier words (`premium`,
`family`, `annual`). Tier words are kept aside rather than thrown away, because they are exactly
what separates two real products that share a root.

`MatchScorer` then compares what is left using three signals, in descending order of trust:

1. **Exact.** The normalised keys are identical. `NETFLIX.COM` and `Netflix` both reduce to
   `netflix`, and that scores 1.00.
2. **Structural.** One name's tokens contain the other's, or the two overlap partially, or one
   key is a substring of the other. `SPOTIFY USA` against `Spotify` scores 0.81 this way.
3. **Fuzzy.** Normalised edit distance, and only above a high similarity threshold. It is
   deliberately capped so it can never carry a match on its own: `Shopify` against `Spotify`
   scores 0.00, not a near miss.

A tier word present on one side and not the other applies a small penalty on top, so a query
naming a specific plan does not collapse into the parent brand.

Measured against a mark titled `Spotify` with the slug `spotify`:

| Query | Score | Signal |
| --- | --- | --- |
| `spotify` | 1.00 | exact |
| `Spotify Premium` | 0.94 | exact, after the tier word is set aside |
| `SPOTIFY USA` | 0.81 | structural |
| `Shopify` | 0.00 | fuzzy, below the threshold |

## Lookup cost

Scoring every mark is fine at a few hundred and not at a few thousand, because the edit distance
inside `MatchScorer` is quadratic in the string lengths, so the cost is linear in the size of the
catalogue. `BundledIconProvider` keeps two structures over the marks to avoid paying it: a map
from normalised key to marks, which answers a name that matches exactly without scoring anything
at all, and an inverted index from token to marks, so a query only ever scores marks that share a
word with it. Neither changes a single score.

Measured on an M-series Mac in a release build:

| Query | Time | Path |
| --- | --- | --- |
| `Netflix` | 4.6 microseconds | exact key hit, nothing is scored |
| `NETFLIX.COM` | 6 microseconds | exact key hit once the TLD is normalised away |
| `NOTION LABS INC` | 275 microseconds | token shortlist, then scored |
| a name sharing no token with any mark | 29.7 milliseconds | falls back to the whole catalogue |

The last row is the one to know about. A query that shares no token with any mark, and whose
key does not even prefix a slug, falls back to scoring the whole catalogue, because a
misspelling has no shared token and edit distance is exactly what should catch it. That case is
rare and slow rather than common and slow.

Loading the 3,453 entry catalogue costs 23 to 25 milliseconds on the same machine, paid by the
first lookup rather than at launch. A phone will be slower than every number here.

## Measuring the tiers against your own names

`probe(_:)` asks every provider in parallel and reports what each one returned and how long it
took. It ignores the short circuit deliberately, so a name the bundled catalogue already knows
still reaches the network tiers, which is the only way to compare them. Expect it to take as long
as the slowest provider rather than as long as the best one.

```swift
let resolver = BrandIconResolver(configuration: .exhaustive)

for probe in await resolver.probe(BrandQuery(name: "NETFLIX.COM")) {
    print(probe.source, probe.milliseconds, probe.topConfidence, probe.candidates.count)
}
```

`.exhaustive` is the matching configuration: it never short circuits, keeps candidates at any
confidence, and returns up to twelve, so nothing is filtered out before you can see it. Each
`ProviderProbe` carries the `source`, the `duration` it took, the `candidates` it found best
first, and a `failure` when it failed rather than simply not matching.

This is the diagnostic path, not the resolution path. It exists so you can decide which tiers are
worth enabling from your own names rather than from someone else's benchmark.
