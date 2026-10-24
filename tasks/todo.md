# La Carto'Poulet v1 — Tasks

Rules for every task: tests pass, build succeeds, SPEC.md boundaries respected, one commit per task. Tasks 3–11 (UI) also pass the "UI check" in SPEC.md.

## Task 1: Tooling + local Supabase + restaurants schema
**Description:** Install what's missing and create the first DB migration: the `restaurants` table with PostGIS and public read access.

**Acceptance criteria:**
- [x] Xcode installed and selected (`xcodebuild -version` works); `xcodegen` installed with Homebrew *(you install Xcode and run the `sudo` command; I do the rest)*. Homebrew refuses installs until then (Command Line Tools too old), so the Supabase CLI runs as `npx supabase@2.121.0` for now
- [x] `supabase start` runs locally; migration creates `restaurants` (spec columns, unique `osm_id`, GIST index on `location`)
- [x] RLS: anyone can read, no one but the service key can write

**Verification:** `supabase db reset` applies cleanly; `supabase test db` passes (anon can't insert); `.gitignore` excludes `.env`, `Config.xcconfig` and Supabase secrets.
**Dependencies:** None
**Files:** `supabase/config.toml`, `supabase/migrations/0001_restaurants.sql`, `supabase/tests/restaurants_test.sql`, `.gitignore`
**Scope:** S

## Task 2: OSM import with the chicken rule
**Description:** `scripts/import_osm.py` (standard library only) fetches mainland France region by region from Overpass, applies the spec's chicken rule and upserts into `restaurants`.

**Acceptance criteria:**
- [x] Applies the 4 spec rules (cuisine, brands, Portuguese/Peruvian + name, name only); words matched case- and accent-insensitively
- [x] Re-running creates no duplicates; prints the count per rule and 20 random matches
- [x] Retries an overloaded server with backoff and saves raw responses to `data/osm/` (git-ignored)

**Verification:** `python3 scripts/import_osm.py --self-test` passes on `scripts/fixtures/overpass_sample.json`; a real run loads 1,000+ rows into local Supabase; you check the 20 sample matches.
**Dependencies:** 1
**Files:** `scripts/import_osm.py`, `scripts/fixtures/overpass_sample.json`, `.gitignore`
**Scope:** S

## Task 3: Xcode project + map centred on the user
**Description:** XcodeGen project with the iOS 17 app target, test target and `supabase-swift` dependency. The app opens on a full-screen map centred on the user's location (fallback: Paris). Adds the Chicken land tokens (`Yolk`, `Comb`, `Feet`, `Crispy`, `Ink`, `Feather`, light + dark), the `chicken-pin` and `drumstick` vectors, and bundles the Shrikhand font (with `OFL.txt`).

**Acceptance criteria:**
- [x] `xcodegen generate` + the spec build command succeed
- [x] Location permission prompt shows a French explanation; on refusal the map shows Paris
- [x] Supabase URL and anon key come from a git-ignored `Config.xcconfig`
- [x] Asset catalog has the 6 colour tokens (spec hex values), `chicken-pin` (from `design/logo-symbol.svg`) and the `drumstick` template icon
- [x] `Font.custom("Shrikhand-Regular", size:, relativeTo:)` renders in a preview and scales with Dynamic Type

**Verification:** build + test commands pass; manual: simulator with a custom location shows that place.
**Dependencies:** 1
**Files:** `project.yml`, `LaCartoPoulet/App.swift`, `LaCartoPoulet/Features/Map/MapView.swift`, `LaCartoPoulet/Assets.xcassets/`, `Config.xcconfig.example`
**Scope:** M

## Task 4: Restaurants appear on the map
**Description:** `restaurants_in_bbox` SQL function; repository + `MapViewModel` load the visible area after the map stops moving and show one marker per restaurant.

**Acceptance criteria:**
- [x] Moving the map loads that area's restaurants (max 500 per request) as chicken-pin markers
- [x] Zoomed out, markers gather into nest clusters (basket, two eggs, count); below the zoom threshold the "Zoome pour voir les restos" pill shows instead
- [x] A network error shows a French error message and keeps the old markers

**Verification:** unit test of `MapViewModel` with a fake repository (load, error keeps old data); SQL test of the bbox function; manual: Paris and Lyon show markers.
**Dependencies:** 2, 3
**Files:** `supabase/migrations/0002_bbox.sql`, `Models/Restaurant.swift`, `Services/RestaurantRepository.swift`, `Features/Map/MapViewModel.swift`, `LaCartoPouletTests/MapViewModelTests.swift`
**Scope:** M

### Checkpoint A
- [x] Tests pass, build clean
- [x] The simulator shows the real imported dataset across France
- [x] You review the chicken rule results before we continue (stricter cuisine rule, 1,742 places)

## Task 5: Restaurant detail sheet
**Description:** `ratings` table, `restaurant_stats` view and read policy (non-hidden only). Tapping a marker opens a sheet with a yolk header (name in Shrikhand, "Fast food à Lyon 7e"), drumstick average, rating count, "Itinéraire" and comments (newest first). Builds the reusable `DrumstickRating` display view.

**Acceptance criteria:**
- [x] Sheet matches the spec's Restaurant sheet; "Pas encore d'avis. Sois le premier !" when empty; "Itinéraire" opens Apple Maps
- [x] Hidden ratings never come back from the API (RLS, not app filtering)
- [x] `DrumstickRating` rounds to the nearest half drumstick, shows "4,3" and reads "4,3 sur 5, 12 avis" in VoiceOver

**Notes:** "Donner mon avis" comes with Task 7 (it needs sign-in); `profiles` is created here because comments need nicknames, Task 6 adds its write policies. Average and count are computed from the loaded ratings; `restaurant_stats` is there for later use.

**Verification:** SQL test (hidden rating unreadable by anon); unit test of the half-rounding (4.3 → 4.5, 4.2 → 4); manual with seeded ratings in light and dark mode, and with the largest Dynamic Type size.
**Dependencies:** 4
**Files:** `supabase/migrations/0003_ratings.sql`, `supabase/seed.sql`, `Models/Rating.swift`, `Features/Restaurant/RestaurantSheet.swift`, `Components/DrumstickRating.swift`
**Scope:** M

## Task 6: Email-code sign-in
**Description:** `profiles` table (public nicknames). Sign-in sheet: enter email, receive a 6-digit code, enter it, choose a nickname the first time, stay signed in across launches. Sign out.

**Acceptance criteria:**
- [x] Full flow works locally (code read from the local Supabase mail viewer)
- [x] Session survives an app relaunch
- [x] Invalid email, wrong code or taken nickname shows a French error; emails are never readable by other users (RLS)

**Notes:** `profiles` already existed (Task 5); `0004_profiles_write.sql` adds insert/update-own policies. The code email uses `supabase/templates/code.html`; hosted Supabase needs the same template set (Task 11). `AccountView` ("Mon compte", opened from the map's top-right button) holds sign-out; Task 9 extends it.

**Verification:** unit test of the sign-in view model states with a fake auth service; manual run in the simulator.
**Dependencies:** 3
**Files:** `supabase/migrations/0004_profiles_write.sql`, `Services/AuthService.swift`, `Features/Account/SignInView.swift`, `Features/Account/AccountViewModel.swift`, `LaCartoPouletTests/AccountViewModelTests.swift`
**Scope:** M

## Task 7: Create / edit / delete my rating
**Description:** RLS write policies on `ratings`. In the sheet, a signed-in user rates 1–5 drumsticks (one VoiceOver-adjustable control) with an optional comment (≤ 1000 chars), then edits or deletes it. Signed-out users are sent to sign-in.

**Acceptance criteria:**
- [x] One rating per user per restaurant (DB unique constraint); a second save updates it
- [x] A user can't change or delete someone else's rating (RLS)
- [x] Average and count update after saving
- [x] Each drumstick value shows its rating word ("Croustillant"…); after "Publier" the marker hops twice, not at all with Reduce Motion

**Notes:** Column grants keep `hidden` out of users' reach (only `stars`/`comment` are updatable). The form edits by id when a rating exists, so no upsert. After saving, the sheet reloads its ratings rather than updating optimistically; the form keeps a spinner on "Publier" and shows errors under it. The repository stayed in `Services/RestaurantRepository.swift`. Open for Task 8: a user whose rating got hidden sees an empty form and a generic error when publishing again (unique constraint).

**Verification:** SQL tests (other user's rating untouchable; 0 or 6 rejected; 1001 chars rejected); unit tests of the form validation; manual loop.
**Dependencies:** 5, 6
**Files:** `supabase/migrations/0005_ratings_write.sql`, `supabase/tests/ratings_test.sql`, `Features/Restaurant/RatingForm.swift`, `Services/RatingRepository.swift`, `LaCartoPouletTests/RatingFormTests.swift`
**Scope:** M

### Checkpoint B
- [x] Tests pass, build clean
- [x] Sign in → rate → see the new average → edit → delete works in the simulator (and on the iPhone against hosted Supabase)
- [x] Review with you

## Task 8: Report a comment + auto-hide at 3 reports
**Acceptance criteria:**
- [x] Signed-in user can report another user's comment once (DB primary key), with a reason
- [x] Trigger sets `hidden = true` at the 3rd report; the comment disappears for everyone
- [x] Can't report your own comment

**Notes:** `rating_list` now returns `user_id` and `is_mine` (false when signed out), so the "…" menu only shows on other people's comments. Reporting twice is treated as done in the app. The author still sees a hidden rating in the form, with a note, so they can edit or delete it; it no longer counts in the average. Reports are write-only for users (nobody can read them through the API).

**Verification:** SQL tests for the trigger and the double-report rejection; manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0006_reports.sql`, `supabase/tests/reports_test.sql`, `Features/Restaurant/ReportSheet.swift`, `Services/RatingRepository.swift`
**Scope:** S

## Task 9: Block a user
**Acceptance criteria:**
- [x] "Bloquer cet utilisateur" on a comment; that user's comments disappear for the blocker (filtered in the ratings query via the `blocks` table)
- [x] The blocked user's ratings still count in the average (they're only hidden from the blocker's view)
- [x] The blocker can see and undo blocks in the Account screen

**Notes:** `rating_list` filters on `blocks`, and RLS keeps each user to their own rows. anon has a select grant but no policy, so the view still works signed out. The sheet header now reads `restaurant_stats`, so a block doesn't change the average. "Bloquer" asks for confirmation and only appears when signed in. The Account screen uses "Débloquer" buttons instead of swipe, because it's a ScrollView, not a List. A failed block shows its error in Mon compte only.

**Verification:** SQL test (blocked user's comment not returned to the blocker, still returned to others); manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0007_blocks.sql`, `supabase/tests/blocks_test.sql`, `Features/Restaurant/RestaurantSheet.swift`, `Features/Account/AccountView.swift`
**Scope:** S

## Task 10: Delete my account
**Acceptance criteria:**
- [x] "Supprimer mon compte" in Account, with a confirmation dialog
- [x] `delete_my_account()` removes the user, their profile, ratings, reports and blocks
- [x] The app returns to the signed-out state

**Notes:** `delete_my_account()` is security definer, deletes only `auth.uid()` from `auth.users`, and the existing cascades handle everything else. Only authenticated users can execute it. The app then signs out locally; the server answers 403 because the session is already gone, and supabase-swift ignores that.

**Verification:** SQL test (all rows gone after the call; a user can only delete themselves); manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0008_delete_account.sql`, `supabase/tests/delete_account_test.sql`, `Features/Account/AccountView.swift`, `Services/AuthService.swift`
**Scope:** S

## Task 11: OSM attribution + hosted Supabase + real-iPhone check
**Description:** Add "© OpenStreetMap contributors" in the map and the Account screen. App icon: export `design/app-icon.svg` to a 1024 px PNG in the asset catalog. Create the free hosted Supabase project *(you create the account; I push migrations and run the import)*. Run the app on your iPhone.

**Acceptance criteria:**
- [x] Attribution visible and links to openstreetmap.org/copyright; placeholder app icon shows on the home screen
- [x] Hosted DB has the schema and the full import
- [x] On your iPhone over 4G, markers appear within 3 s

**Notes:** Hosted project `tnkkgcyeokiuxjtrnyfr`; 8 migrations pushed with no seed; 1,742 restaurants imported (more than the 1,245 of the first import, because OSM grew). Editing the email templates needed custom SMTP, now Resend. The public key can read the map data and nothing private. Config.xcconfig (git-ignored) points at the hosted project.

**Verification:** all tests pass; the spec's manual release checklist passes on the iPhone.
**Dependencies:** 8, 9, 10
**Files:** `Features/Map/MapView.swift`, `Features/Account/AccountView.swift`, `Config.xcconfig.example`
**Scope:** S

### Checkpoint C
- [x] All 7 spec success criteria met (2–6 checked by you on the iPhone over 4G on 2026-10-18; 1 and 7 by the import and the 24 app + 50 DB tests)
- [x] On TestFlight: build 1.0 (1) uploaded 2026-10-24 (team CFQN5S599K)
