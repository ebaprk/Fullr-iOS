# Fullr

Fullr is an iOS app for discovering nearby food offerings from restaurants, pantries, campus providers, and local businesses. The app helps students find available pickups, claim offers, view provider locations on a map, and see community impact stats around rescued food.

## Features

- Email/password authentication backed by Supabase.
- Discover feed with search, provider filters, pickup radius controls, featured offers, and nearby listings.
- Offer detail pages with provider information, claim status, pricing, pickup windows, and related offers from the same provider.
- Map view with user location, nearby offer annotations, and compact offer cards.
- Community stats with provider leaderboards, period filters, provider-type filters, and per-offer claim breakdowns.
- Settings area with account details, claimed offers, pickup reminder preference, student-verified provider filtering, and sign out.

## Tech Stack

- SwiftUI
- Observation
- MapKit and CoreLocation
- Supabase REST/Auth APIs
- Kingfisher for remote image loading
- Bundled Outfit font

## Project Layout

```text
Fullr/Fullr/
├── App/                 Shared app state, styling, and tab navigation
├── Features/
│   ├── Home/            Discover feed, offer cards, and offer details
│   ├── Login/           Sign in and sign up flows
│   ├── Map/             Map-based offer discovery
│   ├── Settings/        Account, preferences, and claimed offers
│   └── Stats/           Claim leaderboards and provider stats
├── Models/              App domain models and stats models
├── Services/            Auth, food offering, stats, geocoding, and Supabase access
├── Assets.xcassets      App icons, logo, and visual assets
└── Fonts/               Outfit font and license
```

The repository also includes `Kingfisher/` as the image-loading package dependency source.

## Getting Started

1. Open the repository in Xcode.
2. Select the Fullr app scheme.
3. Choose an iOS simulator or connected iPhone.
4. Build and run the app.

The app currently expects Supabase configuration in `Fullr/Fullr/Services/SupabaseClientProvider.swift`. The checked-in client points to the configured Fullr Supabase project and uses the public anon key. For another environment, update the Supabase URL and anon key there.

## Supabase Integration

Fullr calls Supabase directly through lightweight service types instead of a generated client. The app uses:

- Supabase Auth for sign in, sign up, session restore, token refresh, and sign out.
- `Offers` and `Stores` REST tables for food offerings and provider metadata.
- `get_offer_claim_status` and `set_offer_claim_status` RPC functions for claims.
- `get_provider_claim_stats` RPC function for provider and offer leaderboards.

The auth callback URL scheme is:

```text
fullr://auth/callback
```

## Design System

Shared styling lives in `Fullr/Fullr/App/FullrStyle.swift`.

The project palette is intentionally limited. Use only these colors anywhere color is specified:

- `#FFF8D9`
- `#AD8820`
- `#90844A`
- `#444F24`
- `#212413`
- `#122311`

Do not introduce extra hex colors, named colors, system colors, gradients with other colors, or opacity-derived variants unless the palette is explicitly updated.

## Development Notes

- Prefer SwiftUI and async/await patterns.
- Keep view-specific logic in feature view models.
- Use the shared `FullrPalette`, `FullrFont`, and button/toggle styles for visual consistency.
- Preserve the custom bottom navigation in `FullrTabView`.
- Use previews and mock services where possible for UI iteration.

## Assets and Fonts

Fullr bundles the Outfit font under `Fullr/Fullr/Fonts/`. The font license is included in `OFL.txt`.

Remote provider images are loaded through Kingfisher when image URLs are available from Supabase.
