# Usalingo iOS SwiftUI

```text
Purpose:
Native iOS app for operator-curated English flashcards.
```

## Current Core Scope

```text
- Email/password auth
- Deck list
- Illustrated word cards
- Correct/incorrect answer
- Save progress to Supabase
- Play operator-provided audio assets
```

## Setup

Create local config:

```text
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Set:

```text
SUPABASE_PROJECT_REF=...
SUPABASE_ANON_KEY=...
```

Then open:

```text
UsalingoIOS.xcodeproj
```

## Dependencies

Swift Package Manager only. CocoaPods and Carthage are not used. The adoption
criteria are in
[the technology stack](../../docs/operations/technology-stack.md#外部パッケージの方針).

Add a package from Xcode (`File > Add Package Dependencies...`). Xcode writes:

```text
UsalingoIOS.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

That path is tracked by Git. The `.swiftpm/` rule in `.gitignore` does not match
it, so no extra setting is needed. Commit `Package.resolved` together with the
change that adds the package.

Call an external package through a thin wrapper in `Services/`, never from a
`View`. See
[the wrapper rule](../../docs/operations/technology-stack.md#薄いラッパの置き方).

## Licenses

The license list is a generated file, not a hand-written one:

```text
sh ../../scripts/generate-licenses.sh
```

It writes `UsalingoIOS/Resources/Licenses/Acknowledgements.md`. Commit that file
with the change that added the dependency. To verify the committed list is not
stale:

```text
sh ../../scripts/generate-licenses.sh --check
```

The command needs macOS and `license-plist` (`brew install licenseplist` or
`mint install mono0926/LicensePlist`). Settings live in `license_plist.yml`.

## Tests

Run the current unit tests on an installed iPhone Simulator:

```text
xcodebuild -project UsalingoIOS.xcodeproj -scheme UsalingoIOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO test
```

## Quality gate

Before calling a build ready for release, record the applicable evidence in
[the quality gate](../../docs/operations/release-quality-gate.md). The checklist separates
ordinary development checks from human-owned release and production checks.

## Auth Note

```text
Create Account may require email confirmation.
After confirming email, use Sign In.
```
