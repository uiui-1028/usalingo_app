# Usalingo iOS SwiftUI MVP

```text
Purpose:
Native iOS MVP for illustrated English flashcards.
```

## MVP Scope

```text
- Email/password auth
- Deck list
- Illustrated word cards
- Correct/incorrect answer
- Save progress to Supabase
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

## Auth Note

```text
Create Account may require email confirmation.
After confirming email, use Sign In.
```
