# Licensing the marks

## Restrictively licensed marks

223 of the 4,770 marks carry recorded terms beyond the set default, some of which forbid commercial use or derivative works,
among them `vuedotjs`, `sass`, `cocoapods` and `letsencrypt`. NonCommercial conflicts with
shipping a paid app. NoDerivatives sits awkwardly with what this package does to every mark,
which is reparse its path and rescale it.

```swift
var configuration = ResolverConfiguration.default
configuration.excludesRestrictiveLicenses = true
```

That drops those thirteen from the catalogue the resolver sees. The default is `false`, matching
what Simple Icons itself ships, because excluding them silently would hide a decision that
belongs to you. Both sets are also available directly, as `BundledCatalog.restrictivelyLicensed`
and `BundledCatalog.permissivelyLicensed`, and `BundledMark.license` reports the terms recorded
for any one mark.

Neither setting is a statement that a given use is permitted. Read [NOTICE](../NOTICE).

## The trademark question

The package is MIT. The bundled marks are a separate question: CC0 covers the drawing, not the
trademark in the thing drawn, and 223 marks carry other terms that `BundledMark.license`
reports, including 13 under NonCommercial or NoDerivatives terms that
[`excludesRestrictiveLicenses`](#restrictively-licensed-marks) can drop. Read [NOTICE](../NOTICE)
before shipping them.
