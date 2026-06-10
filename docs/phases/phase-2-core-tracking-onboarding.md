# Phase 2 — Core Tracking & Onboarding (Weeks 4–8, part 2)

> The everyday product: logging, calendar/timeline, and the onboarding intake that seeds the prediction engine on day one. This is the free-forever core that drives retention and traction.
> References: `prd.md` §5.1, §4.4; `architecture.md` §3, §7; `engineering-practices.md` §3.3.

---

## Objective

A user can onboard (intake that seeds a prior), log everything the MVP tracks, and see it on calendar + timeline — all offline, encrypted, in Vietnamese.

---

## Deliverable milestones

| # | Milestone | Output |
|---|---|---|
| 2.1 | Onboarding intake | Flow capturing last 1–3 period dates, typical cycle length, conditions, birth year → writes `user_profile`, derives `segment` |
| 2.2 | Period logging | Start/end, flow intensity, spotting → `period_events` |
| 2.3 | Symptom/mood/energy/sleep/sex logging | Fine-grained `symptom_entries` / `sex_entries` (one row per date+type) |
| 2.4 | Fertility logging | BBT, cervical mucus, LH strip → `fertility_entries` (manual + HealthKit source tag) |
| 2.5 | Notes & custom tags | Free-text `notes`; user-defined `tags` + `tag_values` |
| 2.6 | Calendar view | Month calendar with logged-day indicators |
| 2.7 | Timeline view | Chronological entry feed, editable/deletable (soft-delete) |
| 2.8 | Local reminders | Period/pill/log-nudge notifications (local only) |
| 2.9 | Design system pass | Warm, non-clinical components in `VeliaDesignSystem`; Vietnamese base locale |

---

## Testable — with instructions

**Unit tests** (`make test`):
- Intake → correct `user_profile` + derived segment + seeded prior handed to engine.
- Each logger writes correct rows; edits update `updated_at`; deletes set `deleted_at`.
- Calendar/timeline view models map repository data correctly (against in-memory fakes).
- Reminder scheduling logic (no real notifications in unit tests).

**Snapshot tests** (`make test-snapshot`):
- Each primary screen (onboarding steps, calendar, timeline, each logger sheet) in light/dark + 2 Dynamic Type sizes.

**UI tests** (`make test-ui`):
- First-run onboarding → home.
- Log a period → calendar + timeline reflect it.
- Log symptom + fertility entries → appear in timeline.
- Edit then soft-delete an entry → removed from view, retained in store.

**Manual:**
```bash
make verify-all      # full gate incl. UI + bench (bench unchanged, must stay green)
```

---

## Checkpoint ("G2 — Tracking complete")

- [ ] Onboarding seeds the engine; a (wide) prediction is computable immediately after intake.
- [ ] All MVP data types log correctly, with fine-grained rows + soft-delete.
- [ ] Calendar + timeline accurately reflect stored data, including after edits/deletes.
- [ ] Local reminders fire; nothing requires network.
- [ ] Default language is **Vietnamese**; no raw string keys visible; copy is informational-not-diagnostic.
- [ ] Snapshot + UI critical-flow tests green; engine benchmark still passes (no regression from integration).

---

## Validation steps

1. `make verify-all` → all gates green (unit, snapshot, UI, privacy invariants, bench).
2. Manual walkthrough on simulator + device: onboard → log a week of varied entries → verify calendar/timeline.
3. Edit and delete entries → confirm soft-delete behavior and UI consistency.
4. Confirm Vietnamese copy throughout; switch to English locale → strings resolve.
5. Schedule a reminder a minute out → confirm it fires offline.
6. Accessibility: VoiceOver reads loggers; Dynamic Type at XXL doesn't break layout.

---

## Exit criteria → Phase 3

Users can fully capture data and the engine has real inputs. Phase 3 surfaces predictions and ships the fertility/insight UI + content + polish.
