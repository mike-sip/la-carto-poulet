# Implementation Plan: La Carto'Poulet v1

Spec: [SPEC.md](../SPEC.md). Tasks with acceptance criteria: [todo.md](todo.md).

## Overview
Native SwiftUI + MapKit iPhone app reading chicken restaurants from Supabase (Postgres + PostGIS). The restaurants come from OpenStreetMap through a Python import script. Visitors browse without an account; email-code sign-in unlocks rating, commenting, reporting, blocking and account deletion.

## Architecture Decisions
- **Local first:** develop against a local Supabase (`supabase start`, Docker). Create the free hosted project only in Task 11, when the app must run on your iPhone outside your Wi-Fi.
- **Map queries:** one Postgres function `restaurants_in_bbox(min_lat, min_lng, max_lat, max_lng)` returns restaurants + stats for the visible area (capped at 500). The app calls it when the user stops moving the map. No client-side cache in v1.
- **All rules in the database:** one rating per user, 1–5 stars, comment ≤ 1000 chars, auto-hide after 3 reports and cascade on account deletion are DB constraints, triggers and row-level security, not app code. The app stays thin.
- **Account deletion:** a `delete_my_account()` SQL function (`security definer`) deletes the caller from `auth.users`; foreign keys cascade.
- **Xcode project defined in `project.yml` (XcodeGen):** a readable text file in git instead of a generated `.xcodeproj`, and I can create and change it from the terminal. It's a dev tool only; nothing ships in the app.
- **Design system = Chicken land (SPEC "Visual identity", `design/mockup.html`):** 6 colour tokens (light/dark), Shrikhand for display text, chicken-pin and drumstick vectors, nest clusters, one hop animation; everything else iOS system styles. Logo and app icon already exist in `design/`. Design work is folded into the feature tasks (3, 4, 5, 7, 11) rather than a separate design phase.
- **Import:** Overpass queried region by region (13 mainland regions) with retries, because the public servers were overloaded when I tested. Upsert on `osm_id`.

## Dependency Graph
```
Tooling + DB schema (1)
   ├── OSM import (2)
   └── Xcode skeleton + map (3) ── restaurants on map (4) ── detail sheet (5)
                                                                   │
                                     email sign-in (6) ── my rating (7)
                                                            ├── report + auto-hide (8)
                                                            ├── block (9)
                                                            └── delete account (10)
                                                                   └── attribution + real device (11)
```
The riskiest part (OSM data volume and quality) comes first: Task 2.

## Task List
### Phase 1: Data and map
- [ ] 1. Tooling + local Supabase + restaurants schema
- [ ] 2. OSM import with the chicken rule
- [ ] 3. Xcode project + map centred on the user
- [ ] 4. Restaurants appear on the map
### Checkpoint A: the simulator shows the real France dataset on the map
### Phase 2: Ratings
- [ ] 5. Restaurant detail sheet (ratings schema + read)
- [ ] 6. Email-code sign-in + nickname
- [ ] 7. Create / edit / delete my rating
### Checkpoint B: full rate-and-read loop works in the simulator
### Phase 3: Safety and release
- [ ] 8. Report a comment + auto-hide at 3 reports
- [ ] 9. Block a user
- [ ] 10. Delete my account
- [ ] 11. OSM attribution + hosted Supabase + real-iPhone check
### Checkpoint C: all 7 spec success criteria met

## Parallelization
Tasks 2 and 3 are independent after Task 1. Tasks 8, 9 and 10 are independent after Task 7. Everything else is sequential.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Xcode not installed (only Command Line Tools are active) | High: blocks Tasks 3+ | Task 1: install Xcode from the App Store, then `sudo xcode-select -s /Applications/Xcode.app` |
| Public Overpass servers overloaded | Med | Query per region, retry with backoff, try 2 mirrors; save the raw JSON so re-runs can work offline |
| Name-based chicken rule adds false positives ("Pollo" in a pizzeria name) or misses places | Med | Import prints the count per rule plus 20 random matches to eyeball; tune the word list before Checkpoint A |
| Supabase's built-in email sender allows only a few emails per hour | Low in dev, High at launch | Fine for development; add a free SMTP provider (e.g. Resend) before TestFlight. Out of v1 scope |
| Free hosted Supabase project pauses after 7 days of inactivity | Low | Resume it from the dashboard; it stops mattering once real users are active |
| Free Apple account: the app on your iPhone expires after 7 days | Low | Reinstall from Xcode; no impact on development |

## Open Questions
None.
