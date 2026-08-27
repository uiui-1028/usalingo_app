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
