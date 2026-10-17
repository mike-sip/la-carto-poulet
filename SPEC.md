# Spec: La Carto'Poulet

Status: v6, Chicken land design and logo added; waiting for approval.

## Objective

An iOS app for chicken lovers in mainland France: a map of chicken restaurants (fast food and sit-down), where people can rate and comment.

**User stories (v1)**
- As a visitor, I open the app and see chicken restaurants near me on a map, without creating an account.
- As a visitor, I tap a marker and see the restaurant's name, address, type (fast food / restaurant), average rating, number of ratings and its comments.
- As a signed-in user, I give a restaurant 1–5 drumsticks and an optional comment. I can edit or delete it later. I get one rating per restaurant.
- As a user, I can report a comment and block another user. A comment with 3 or more reports is hidden automatically until the admin reviews it. (App Store guideline 1.2.)
- As a user, I can delete my account and all my data from inside the app. (App Store guideline 5.1.1(v).)

**Out of v1:** menus (OpenStreetMap has no menu data; see below), users suggesting missing restaurants, overseas France (DOM-TOM), photos, search, filters, favorites, Android, web, push notifications.

## Restaurant data

Source: OpenStreetMap, imported by a script. Free, and the data can be stored under the ODbL licence ("© OpenStreetMap contributors" attribution required).

**No menus.** OpenStreetMap doesn't store menus: only 1 place in all of France has a menu link (`menu:url`). "Serves chicken" can't be detected from the data, and almost every restaurant serves some chicken anyway. So the app maps **chicken-specialist** places.

**Rule: what counts as chicken**, for places with `amenity=restaurant` or `amenity=fast_food` in mainland France:

| Rule | France count (taginfo, Oct 2026, all object types) |
|---|---|
| `cuisine` includes `chicken`, `fried_chicken` or `rotisserie` | ~1,130 |
| `brand` is in the chain list: KFC, Popeyes, Chicken Street, Hungry Chicken… (you complete the list) | KFC alone ~415, mostly overlapping the row above |
| `cuisine` includes `portuguese` or `peruvian` **and** the name matches the chicken words below | subset of ~350 |
| Any restaurant or fast food whose name matches the chicken words below | catches untagged places |

Chicken words (case- and accent-insensitive): `poulet`, `chicken`, `frango`, `pollo`, `brasa`, `churrasc`, `rôtisserie`, `wings`, `tenders`.

Expected v1 size: roughly 1,200–1,600 restaurants; the import script prints the real count per rule. Places missing from OpenStreetMap won't appear until the "suggest a restaurant" feature exists (v1.1 candidate).

## Key decisions

| Topic | Choice | Why |
|---|---|---|
| Platform | iOS 17+, iPhone only | Modern SwiftUI and MapKit APIs |
| UI | SwiftUI + MapKit (Apple Maps) | Free, no map SDK or API key |
| Language | French UI only | The app only covers France |
| Backend | **Supabase** (Postgres + PostGIS, Auth, row-level security) | See below |
| Auth | Email + 6-digit code (Supabase OTP) in v1. Sign in with Apple can be added once the Apple Developer account is paid | Works with a free Apple account. Email isn't a "social login", so Apple doesn't require Sign in with Apple alongside it |
| Data refresh | Re-run the import script by hand (monthly) | No infrastructure in v1 |

**Why Supabase rather than CloudKit:** CloudKit needs the paid Apple Developer account even during development, and it can't run server-side logic like computing average ratings or auto-hiding a comment after 3 reports. It also locks the data to Apple, which blocks a later Android or web version. Supabase works today for free, all of that is plain SQL, and reports can be moderated from its dashboard. Cost: one free-tier Supabase project (it pauses after 7 days without activity until the app is live).

**Without a paid Apple account:** you can build and test in the iOS Simulator and on your own iPhone, but the app must be reinstalled from Xcode every 7 days. Paying the 99 €/year is required only for TestFlight and the App Store.

## UX/UI

**Direction: "Chicken land" (Le Pays du Poulet).** Funny on the map and in the words, calm everywhere else so a restaurant is found in three seconds. The theme comes from the Bresse chicken (red comb, white feathers, blue feet), egg yolk and hand-painted rôtisserie signs. Standard SwiftUI structure (sheets, lists, automatic dark mode). Reference mockup: `design/mockup.html` (open it in a browser).

**Logo:** a chicken-shaped map pin whose foot is the pin's tip ("la patte marque l'endroit"). Files in `design/`: `logo-symbol.svg` (chicken pin, also the map marker), `logo.svg` / `logo-dark.svg` (symbol + "La Carto'Poulet" wordmark in Shrikhand; the apostrophe is a small red comb), `app-icon.svg` (chicken pin on yolk yellow).

### Screens and flow
```
Map (home) ──tap marker──▶ Restaurant sheet ──"Donner mon avis"──▶ Rating form
   │                          │    └─ signed out? ─▶ Sign-in sheet ─▶ back to Rating form
   │                          ├─ "Itinéraire" → opens Apple Maps directions
   │                          └─ "…" on a comment → Signaler / Bloquer
   └─ person icon (top right) ─▶ Account (sign in/out, blocked users, OSM credit, delete account)
```
1. **Map:** full screen. Chicken-pin markers; they gather into nests when zoomed out, and below a zoom threshold a "Zoome pour voir les restos" pill replaces them. "Ma position" button. First launch: system location prompt with a French explanation; on refusal, the map opens on Paris.
2. **Restaurant sheet:** bottom sheet, half then full height. Yolk header: name, "Fast food à Lyon 7e", drumstick average + "12 avis", buttons "Donner mon avis" (`Comb`, filled) and "Itinéraire" (opens Apple Maps). Comments newest first: author nickname, drumsticks, date, text. Empty: "Pas encore d'avis. Sois le premier !"
3. **Rating form:** title "Alors, ce poulet ?", 5 tappable drumsticks with the rating word under them, comment field with a "0/1000" counter, "Publier". If the user already rated: prefilled, plus "Supprimer mon avis".
4. **Sign-in sheet:** email → "Recevoir le code" → 6-digit code field (iOS autofill from Mail) → first time only: choose a nickname (3–20 chars, unique) → done. The email is never shown to other users.
5. **Account:** email, nickname, blocked users (swipe to unblock), "Données © OpenStreetMap contributors", "Se déconnecter", "Supprimer mon compte" (red, confirmation dialog).
6. **Report sheet:** reasons "Insultant", "Spam", "Hors sujet", "Autre".

Errors: a short banner "Pas de connexion. Les poulets déjà affichés restent là." that keeps the data already shown and retries by itself.

### Visual identity
| Token | Light | Dark | Use | Contrast (checked) |
|---|---|---|---|---|
| `Yolk` "Jaune d'œuf" | `#FFC425` | `#FFC425` | sheet headers, brand pill, app icon | `Ink` text on it 10.0:1 |
| `Comb` "Crête" | `#C1121F` | `#FF6B78` | primary buttons ("Donner mon avis", "Publier"), errors | white text on light 6.2:1; `#14213D` text on dark 5.8:1 |
| `Feet` "Pattes de Bresse" | `#2448C9` | `#7FA2FF` | links, secondary actions ("Itinéraire"), focused fields | 7.4:1 / 6.5:1 |
| `Crispy` "Croustillant" | `#8A4B0F` | `#E2A04A` | filled drumsticks | 6.8:1 / 7.1:1 on background; 4.3:1 on yolk (icons need 3:1, the number beside them is `Ink`) |
| `Ink` "Encre" | `#14213D` | `#FFFFFF` | text | 16.0:1 |
| `Feather` "Plume" | `#FFFFFF` | `#14213D` | background | — |

Secondary text uses `.secondary` (system). All text pairs pass WCAG AA (4.5:1). Tokens live in the asset catalog with light and dark variants.

- **Type:** **Shrikhand** (Google Fonts, SIL OFL, bundled in the app with `OFL.txt`; source `design/fonts/`) for display only: restaurant names, screen titles, the big rating number, the verdict word. SF Pro (system) for everything else. Shrikhand uses `Font.custom("Shrikhand-Regular", size:, relativeTo:)` so it scales with Dynamic Type.
- **Map markers:** the chicken pin (`logo-symbol.svg`). Clusters are **nests**: a basket with two eggs and the count in white on the basket.
- **Restaurant sheet header:** yolk background, name in Shrikhand, "Fast food à Lyon 7e" (a sentence, no "type · city"), then "4,3" in Shrikhand + drumsticks + "12 avis".
- **Rating display:** 5 drumsticks, the average rounded to the nearest half (half-filled drumstick), followed by the number with one decimal ("4,3"). Empty drumsticks are a pale bone colour.
- **Rating words** (shown under the drumsticks in the form, and read by VoiceOver): 1 "Sec comme un vieux pneu", 2 "Bof", 3 "Bon poulet", 4 "Croustillant", 5 "Cocorico".
- **One motion moment:** after "Publier", the restaurant's chicken marker hops twice. Off when Reduce Motion is on. No other decorative animation.
- **Tone:** casual, using "tu", chicken words in titles ("Alors, ce poulet ?", "Rejoins le poulailler", "Pas un poulet à l'horizon"). Errors stay plain and say what to do. No ALL CAPS labels, no "→" in buttons, no "A · B" meta strings.
- **Rejected:** orange/terracotta accent, cream background, cards with soft shadows, gradients.

### Accessibility
- Dynamic Type everywhere; no fixed font sizes.
- VoiceOver: a rating reads "4,3 sur 5, 12 avis"; the drumstick input is one adjustable control ("3 sur 5, Bon poulet", swipe up/down); markers read the restaurant name.
- Tap targets at least 44 × 44 pt; colour is never the only signal (the number is always shown next to the drumsticks).

### Screen states
Every screen handles each state that applies; no blank screens.

| Screen | Job / primary action | Loading | Empty | Error | Permission / auth |
|---|---|---|---|---|---|
| Map | find a chicken place nearby / tap a marker | old markers stay, small spinner in the "Ma position" button | "Aucun resto poulet ici. Déplace la carte !" pill | banner "Pas de connexion, réessaie" + old markers kept | location refused → Paris + "Activer la localisation" link to Settings |
| Restaurant sheet | judge the place / "Donner mon avis" | header shows at once (data from the map); comments use `.redacted(reason: .placeholder)` rows | "Pas encore d'avis. Sois le premier !" | inline "Impossible de charger les avis" + "Réessayer" | signed out → "Donner mon avis" opens sign-in first |
| Rating form | post a rating / "Publier" | "Publier" shows a spinner and is disabled | — (prefilled if editing) | the form stays filled, error under the button | requires sign-in |
| Sign-in | get signed in / "Recevoir le code" | button spinner | — | under the field: invalid email, wrong or expired code, nickname taken | — |
| Account | manage account / none | — | "Aucun utilisateur bloqué" | inline under the action | signed out → shows only the sign-in button + OSM credit |

Saving a rating updates the sheet right away (optimistic) and rolls back with the error banner if the server refuses.

### Layout and type scale
- **Spacing:** 4-pt scale only: 4, 8, 12, 16, 24, 32. Screen margins 16. No other values.
- **Corner radius:** iOS defaults (sheets, buttons with `.borderedProminent`); the one custom radius is the zoom pill (capsule).
- **Type:** iOS text styles (Shrikhand scales relative to one): restaurant name and screen titles Shrikhand relative to `.title2`, section titles `.headline`, body `.body`, meta lines ("Fast food à Lyon 7e", date) `.subheadline` in `.secondary`. No fixed sizes.
- **Shadows and gradients:** none, except the system ones (sheets, map controls) and the floating brand pill.
- **Supported sizes:** iPhone SE (4.7") to Pro Max, portrait only in v1, all Dynamic Type sizes up to AX5 (layouts switch to vertical stacks when needed).

### Component rules
- Views stay under ~200 lines; split into subviews.
- Screens get data from an `@Observable` view model; reusable components (`DrumstickRating`, `RatingRow`, `ErrorBanner`) only take plain values and closures, so they work in SwiftUI previews and tests.
- Every reusable component has a `#Preview` in light, dark and AX5 Dynamic Type.
- Colours only through the asset-catalog tokens (`Color.yolk`, `.comb`, `.feet`, `.crispy`, `.ink`, `.feather`) and system semantic colours; no hex values in Swift code.

### UI check (each UI task must pass)
- [ ] All states in the table above that apply to the screen are visible in previews or the simulator
- [ ] VoiceOver: every control has a French label, and the order is logical (Xcode Accessibility Inspector audit has no warnings)
- [ ] Light + dark mode, and Dynamic Type AX5, on iPhone SE and Pro Max simulators: nothing cut off or overlapping
- [ ] Tap targets ≥ 44 pt
- [ ] No spacing, font size or colour outside the scales above

## Commands

```
Build:  xcodebuild -scheme LaCartoPoulet -destination 'platform=iOS Simulator,name=iPhone 16' build
Test:   xcodebuild -scheme LaCartoPoulet -destination 'platform=iOS Simulator,name=iPhone 16' test
Import: python3 scripts/import_osm.py        # Overpass → Supabase restaurants table (upsert on osm_id)
DB:     supabase db push                     # apply migrations in supabase/migrations
```

## Project Structure

```
LaCartoPoulet/            → Xcode app target (SwiftUI)
  Features/Map/           → map screen, markers, location permission
  Features/Restaurant/    → detail sheet, rating list, rating form, report/block
  Features/Account/       → email sign-in, account deletion
  Services/               → Supabase client, repositories
  Models/                 → Restaurant, Rating
LaCartoPouletTests/       → unit tests (Swift Testing)
supabase/migrations/      → SQL schema, RLS policies, stats view, auto-hide trigger
supabase/tests/           → RLS tests
scripts/import_osm.py     → OSM import (+ its self-test)
SPEC.md                   → this file
```

## Data Model

```sql
restaurants (id, osm_id unique, name, kind ('fast_food'|'restaurant'), address, city,
             location geography(Point), brand, cuisine, updated_at)
ratings     (id, restaurant_id → restaurants, user_id → auth.users, stars 1..5, comment ≤ 1000 chars,
             hidden bool default false, created_at, updated_at, unique(restaurant_id, user_id))
profiles    (user_id → auth.users primary key, nickname unique 3..20 chars)
reports     (rating_id, reporter_id, reason, created_at, primary key (rating_id, reporter_id))
blocks      (blocker_id, blocked_id, primary key both)
restaurant_stats (view: restaurant_id, avg_stars, rating_count)
```
- Row-level security: anyone can read restaurants and non-hidden ratings. Users can write only their own ratings, reports and blocks. Restaurants are written only by the import script with the service key.
- Trigger: when a rating reaches 3 reports, set `hidden = true`. The admin un-hides or deletes it in the Supabase dashboard.
- Deleting a user cascades to their profile, ratings, reports and blocks.
- Profiles (nicknames) are publicly readable; emails are never exposed by the API.

## Code Style

Swift API Design Guidelines, SwiftUI with `@Observable` view models, async/await, no third-party dependency except `supabase-swift`.

```swift
@Observable
final class MapViewModel {
    private(set) var restaurants: [Restaurant] = []
    private let repository: RestaurantRepository

    init(repository: RestaurantRepository) { self.repository = repository }

    func load(in region: MKCoordinateRegion) async {
        restaurants = (try? await repository.restaurants(in: region)) ?? restaurants
    }
}
```

## Testing Strategy

- **Unit (Swift Testing):** view models against a fake repository: rating validation, average display, block filtering.
- **DB:** SQL tests in `supabase/tests`: a user can't edit another user's rating; 3 reports hide a rating; deleting a user removes their data.
- **Import script:** assert-based self-test on a saved Overpass sample (the chicken rule, re-import doesn't duplicate).
- **Manual:** before each release, on a real iPhone: location, map, sign-in, rating, report, block, account deletion.
- No coverage target in v1.

## Boundaries

- **Always:** keep the Supabase service key out of the app and the repo (anon key only in the app), show the OpenStreetMap attribution, run the tests before committing.
- **Ask first:** adding any dependency besides `supabase-swift`, changing the DB schema after v1 ships, changing the chicken rule, anything that costs money.
- **Never:** expose users' emails, commit secrets, store users' location on the server, ship user comments without report/block.

## Success Criteria (v1 is done when)

1. The import loads mainland France with the chicken rule, and re-running it creates no duplicates.
2. On a real iPhone, the map shows nearby chicken restaurants within 3 s on 4G, anywhere in mainland France.
3. Tapping a marker shows name, address, type, average drumsticks, rating count and visible comments; "Itinéraire" opens Apple Maps.
4. A signed-in user can create, edit and delete their rating; the average updates on reopen.
5. Report and block work; a comment with 3 reports disappears for everyone; a blocked user's comments are hidden for the user who blocked them.
6. Account deletion removes the user and all their data.
7. All tests listed above pass.

(TestFlight and App Store submission come after v1, once the developer account is paid.)

## Decisions log

- Map: Apple MapKit (iOS-only, free, no key). Data is independent of the map, so switching to Google Maps or Mapbox later only touches the map screen.
- Portuguese and Peruvian places are included only when their name shows they serve chicken (OSM can't tell what a place serves).
- Chain list for v1: KFC, Popeyes, Chicken Street, Hungry Chicken.
- "Suggest a missing restaurant" moves to v1.1.
- UI: native iOS + brand touch; ratings shown as drumsticks 🍗 1–5 (custom icon, accessible); no brand assets exist, so the spec defines palette, icon direction and tone.

## Open Questions

None.
