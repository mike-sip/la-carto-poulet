# La Carto'Poulet v1 — Tasks

Rules for every task: tests pass, build succeeds, SPEC.md boundaries respected, one commit per task. Tasks 3–11 (UI) also pass the "UI check" in SPEC.md.

## Task 1: Tooling + local Supabase + restaurants schema
**Description:** Install what's missing and create the first DB migration: the `restaurants` table with PostGIS and public read access.

**Acceptance criteria:**
- [ ] Xcode installed and selected (`xcodebuild -version` works); `xcodegen` installed with Homebrew *(you install Xcode and run the `sudo` command; I do the rest)*. Homebrew refuses installs until then (Command Line Tools too old), so the Supabase CLI runs as `npx supabase@2.121.0` for now
- [x] `supabase start` runs locally; migration creates `restaurants` (spec columns, unique `osm_id`, GIST index on `location`)
- [x] RLS: anyone can read, no one but the service key can write

**Verification:** `supabase db reset` applies cleanly; `supabase test db` passes (anon can't insert); `.gitignore` excludes `.env`, `Config.xcconfig` and Supabase secrets.
**Dependencies:** None
**Files:** `supabase/config.toml`, `supabase/migrations/0001_restaurants.sql`, `supabase/tests/restaurants_test.sql`, `.gitignore`
**Scope:** S

## Task 2: OSM import with the chicken rule
**Description:** `scripts/import_osm.py` (standard library only) fetches mainland France region by region from Overpass, applies the spec's chicken rule and upserts into `restaurants`.

**Acceptance criteria:**
- [ ] Applies the 4 spec rules (cuisine, brands, Portuguese/Peruvian + name, name only); words matched case- and accent-insensitively
- [ ] Re-running creates no duplicates; prints the count per rule and 20 random matches
- [ ] Retries an overloaded server with backoff and saves raw responses to `data/osm/` (git-ignored)

**Verification:** `python3 scripts/import_osm.py --self-test` passes on `scripts/fixtures/overpass_sample.json`; a real run loads 1,000+ rows into local Supabase; you check the 20 sample matches.
**Dependencies:** 1
**Files:** `scripts/import_osm.py`, `scripts/fixtures/overpass_sample.json`, `.gitignore`
**Scope:** S

## Task 3: Xcode project + map centred on the user
**Description:** XcodeGen project with the iOS 17 app target, test target and `supabase-swift` dependency. The app opens on a full-screen map centred on the user's location (fallback: Paris). Adds the Chicken land tokens (`Yolk`, `Comb`, `Feet`, `Crispy`, `Ink`, `Feather`, light + dark), the `chicken-pin` and `drumstick` vectors, and bundles the Shrikhand font (with `OFL.txt`).

**Acceptance criteria:**
- [ ] `xcodegen generate` + the spec build command succeed
- [ ] Location permission prompt shows a French explanation; on refusal the map shows Paris
- [ ] Supabase URL and anon key come from a git-ignored `Config.xcconfig`
- [ ] Asset catalog has the 6 colour tokens (spec hex values), `chicken-pin` (from `design/logo-symbol.svg`) and the `drumstick` template icon
- [ ] `Font.custom("Shrikhand-Regular", size:, relativeTo:)` renders in a preview and scales with Dynamic Type

**Verification:** build + test commands pass; manual: simulator with a custom location shows that place.
**Dependencies:** 1
**Files:** `project.yml`, `LaCartoPoulet/App.swift`, `LaCartoPoulet/Features/Map/MapView.swift`, `LaCartoPoulet/Assets.xcassets/`, `Config.xcconfig.example`
**Scope:** M

## Task 4: Restaurants appear on the map
**Description:** `restaurants_in_bbox` SQL function; repository + `MapViewModel` load the visible area after the map stops moving and show one marker per restaurant.

**Acceptance criteria:**
- [ ] Moving the map loads that area's restaurants (max 500 per request) as chicken-pin markers
- [ ] Zoomed out, markers gather into nest clusters (basket, two eggs, count); below the zoom threshold the "Zoome pour voir les restos" pill shows instead
- [ ] A network error shows a French error message and keeps the old markers

**Verification:** unit test of `MapViewModel` with a fake repository (load, error keeps old data); SQL test of the bbox function; manual: Paris and Lyon show markers.
**Dependencies:** 2, 3
**Files:** `supabase/migrations/0002_bbox.sql`, `Models/Restaurant.swift`, `Services/RestaurantRepository.swift`, `Features/Map/MapViewModel.swift`, `LaCartoPouletTests/MapViewModelTests.swift`
**Scope:** M

### Checkpoint A
- [ ] Tests pass, build clean
- [ ] The simulator shows the real imported dataset across France
- [ ] You review the chicken rule results before we continue

## Task 5: Restaurant detail sheet
**Description:** `ratings` table, `restaurant_stats` view and read policy (non-hidden only). Tapping a marker opens a sheet with a yolk header (name in Shrikhand, "Fast food à Lyon 7e"), drumstick average, rating count, "Itinéraire" and comments (newest first). Builds the reusable `DrumstickRating` display view.

**Acceptance criteria:**
- [ ] Sheet matches the spec's Restaurant sheet; "Pas encore d'avis. Sois le premier !" when empty; "Itinéraire" opens Apple Maps
- [ ] Hidden ratings never come back from the API (RLS, not app filtering)
- [ ] `DrumstickRating` rounds to the nearest half drumstick, shows "4,3" and reads "4,3 sur 5, 12 avis" in VoiceOver

**Verification:** SQL test (hidden rating unreadable by anon); unit test of the half-rounding (4.3 → 4.5, 4.2 → 4); manual with seeded ratings in light and dark mode, and with the largest Dynamic Type size.
**Dependencies:** 4
**Files:** `supabase/migrations/0003_ratings.sql`, `supabase/seed.sql`, `Models/Rating.swift`, `Features/Restaurant/RestaurantSheet.swift`, `Components/DrumstickRating.swift`
**Scope:** M

## Task 6: Email-code sign-in
**Description:** `profiles` table (public nicknames). Sign-in sheet: enter email, receive a 6-digit code, enter it, choose a nickname the first time, stay signed in across launches. Sign out.

**Acceptance criteria:**
- [ ] Full flow works locally (code read from the local Supabase mail viewer)
- [ ] Session survives an app relaunch
- [ ] Invalid email, wrong code or taken nickname shows a French error; emails are never readable by other users (RLS)

**Verification:** unit test of the sign-in view model states with a fake auth service; manual run in the simulator.
**Dependencies:** 3
**Files:** `supabase/migrations/0003b_profiles.sql`, `Services/AuthService.swift`, `Features/Account/SignInView.swift`, `Features/Account/AccountViewModel.swift`, `LaCartoPouletTests/AccountViewModelTests.swift`
**Scope:** M

## Task 7: Create / edit / delete my rating
**Description:** RLS write policies on `ratings`. In the sheet, a signed-in user rates 1–5 drumsticks (one VoiceOver-adjustable control) with an optional comment (≤ 1000 chars), then edits or deletes it. Signed-out users are sent to sign-in.

**Acceptance criteria:**
- [ ] One rating per user per restaurant (DB unique constraint); a second save updates it
- [ ] A user can't change or delete someone else's rating (RLS)
- [ ] Average and count update after saving
- [ ] Each drumstick value shows its rating word ("Croustillant"…); after "Publier" the marker hops twice, not at all with Reduce Motion

**Verification:** SQL tests (other user's rating untouchable; 0 or 6 rejected; 1001 chars rejected); unit tests of the form validation; manual loop.
**Dependencies:** 5, 6
**Files:** `supabase/migrations/0004_ratings_write.sql`, `supabase/tests/ratings_test.sql`, `Features/Restaurant/RatingForm.swift`, `Services/RatingRepository.swift`, `LaCartoPouletTests/RatingFormTests.swift`
**Scope:** M

### Checkpoint B
- [ ] Tests pass, build clean
- [ ] Sign in → rate → see the new average → edit → delete works in the simulator
- [ ] Review with you

## Task 8: Report a comment + auto-hide at 3 reports
**Acceptance criteria:**
- [ ] Signed-in user can report another user's comment once (DB primary key), with a reason
- [ ] Trigger sets `hidden = true` at the 3rd report; the comment disappears for everyone
- [ ] Can't report your own comment

**Verification:** SQL tests for the trigger and the double-report rejection; manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0005_reports.sql`, `supabase/tests/reports_test.sql`, `Features/Restaurant/ReportSheet.swift`, `Services/RatingRepository.swift`
**Scope:** S

## Task 9: Block a user
**Acceptance criteria:**
- [ ] "Bloquer cet utilisateur" on a comment; that user's comments disappear for the blocker (filtered in the ratings query via the `blocks` table)
- [ ] The blocked user's ratings still count in the average (they're only hidden from the blocker's view)
- [ ] The blocker can see and undo blocks in the Account screen

**Verification:** SQL test (blocked user's comment not returned to the blocker, still returned to others); manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0006_blocks.sql`, `supabase/tests/blocks_test.sql`, `Features/Restaurant/RestaurantSheet.swift`, `Features/Account/AccountView.swift`
**Scope:** S

## Task 10: Delete my account
**Acceptance criteria:**
- [ ] "Supprimer mon compte" in Account, with a confirmation dialog
- [ ] `delete_my_account()` removes the user, their profile, ratings, reports and blocks
- [ ] The app returns to the signed-out state

**Verification:** SQL test (all rows gone after the call; a user can only delete themselves); manual.
**Dependencies:** 7
**Files:** `supabase/migrations/0007_delete_account.sql`, `supabase/tests/delete_account_test.sql`, `Features/Account/AccountView.swift`, `Services/AuthService.swift`
**Scope:** S

## Task 11: OSM attribution + hosted Supabase + real-iPhone check
**Description:** Add "© OpenStreetMap contributors" in the map and the Account screen. App icon: export `design/app-icon.svg` to a 1024 px PNG in the asset catalog. Create the free hosted Supabase project *(you create the account; I push migrations and run the import)*. Run the app on your iPhone.

**Acceptance criteria:**
- [ ] Attribution visible and links to openstreetmap.org/copyright; placeholder app icon shows on the home screen
- [ ] Hosted DB has the schema and the full import
- [ ] On your iPhone over 4G, markers appear within 3 s

**Verification:** all tests pass; the spec's manual release checklist passes on the iPhone.
**Dependencies:** 8, 9, 10
**Files:** `Features/Map/MapView.swift`, `Features/Account/AccountView.swift`, `Config.xcconfig.example`
**Scope:** S

### Checkpoint C
- [ ] All 7 spec success criteria met
- [ ] Ready for TestFlight once the Apple Developer account is paid
