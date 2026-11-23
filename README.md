# Fullr for iOS

An iOS app for discovering nearby food offerings from restaurants, pantries, campus providers, and local businesses. It is the student-facing companion to the [Fullr business web app](https://github.com/ebaprk/Fullr-WebApp).

## Features

- Email/password authentication through Supabase.
- Searchable offer discovery with provider and pickup-radius filters.
- Offer details, claim confirmation, and a saved claimed-offers list.
- MapKit-based location browsing.
- Provider leaderboards and per-offer claim statistics.

## Requirements

- macOS with Xcode and an iOS SDK that supports the checked-in deployment targets.
- iOS 26.0 or later for the app target.
- Internet access to resolve Swift Package Manager dependencies.

## Run locally

```sh
git clone https://github.com/ebaprk/Fullr-iOS.git
cd Fullr-iOS
open "Fullr.xcodeproj"
```

In Xcode, allow package resolution to finish, select the **Fullr** app scheme and a compatible simulator or connected iPhone, then build and run. For a device build, select your development team and update signing identifiers for your own environment.

## Configuration

Set your Supabase project URL and public anon/publishable key in `Fullr/Services/SupabaseClientProvider.swift`. Configure the `fullr://auth/callback` redirect for email confirmation and keep the app URL scheme aligned with Supabase Auth. The app uses lightweight REST/Auth service types rather than the Supabase Swift SDK; Kingfisher is resolved through Swift Package Manager.

The client expects shared `Offers` and `Stores` tables and the `get_offer_claim_status`, `set_offer_claim_status`, and `get_provider_claim_stats` RPCs. Follow the [database guide](supabase/README.md) for migration order and existing-schema checks. Student registration and business-owner registration have separate profile contracts; see the web app’s [mobile handoff](https://github.com/ebaprk/Fullr-WebApp/blob/main/MOBILE_AUTH_HANDOFF.md).

## Project guide

| Location | Purpose |
| --- | --- |
| [Fullr/App/](Fullr/App/) | App state, shared styles, and tab navigation. |
| [Fullr/Features/](Fullr/Features/) | Discover, login, map, settings, and stats screens. |
| [Fullr/Models/](Fullr/Models/) | Domain and statistics models. |
| [Fullr/Services/](Fullr/Services/) | Authentication, offers, stats, geocoding, and Supabase transport. |
| [Fullr/Resources/Fonts/](Fullr/Resources/Fonts/) | Bundled Outfit font and its license. |
| [supabase/](supabase/) | Claim/statistics migrations and database notes. |
| [Tests/](Tests/) | Focused Swift and SQL regression checks. |

## Verify changes

On a Mac with the required Xcode/macOS toolchain, run:

```sh
bash Tests/run-address-geocoder-tests.sh
bash Tests/run-offer-claim-tests.sh
bash Tests/run-stats-tests.sh
```

These scripts compile for macOS 26.0. The [database guide](supabase/README.md) explains the separate PGlite SQL checks and manual authenticated verification. Claim totals represent current user confirmations; they do not establish completed pickups or lifetime redemption counts.

## Design conventions

Use `Fullr/App/FullrStyle.swift` and the palette defined in [AGENTS.md](AGENTS.md). Keep view logic in feature view models and preserve the shared navigation and component styles. The bundled Outfit font’s license is [included with the font](Fullr/Resources/Fonts/OFL.txt).
