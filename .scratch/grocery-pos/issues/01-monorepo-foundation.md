# 01: Monorepo Foundation & Workspace Setup

**What to build:**
Scaffold the multi-package Flutter and Dart monorepo containing `apps/mobile` (Android POS), `apps/desktop` (Windows Admin), `packages/billing_engine` (pure Dart decimal calculation engine), `packages/database` (Drift SQLite persistence), and `packages/sync_protocol` (shared DTOs and network contracts). Configure root analysis options, dependencies, and verify base build targets.

**Blocked by:**
None (can start immediately).

**Status:**
resolved

**Acceptance Criteria:**
- [x] Directory layout created: `apps/mobile`, `apps/desktop`, `packages/billing_engine`, `packages/database`, `packages/sync_protocol`.
- [x] Shared Dart packages have clean `pubspec.yaml` without unnecessary Flutter UI coupling.
- [x] Root `analysis_options.yaml` configured with strict linting rules.
- [x] Base `pub get` runs cleanly across all workspace packages.

## Answer
Monorepo layout created and verified:
- `apps/mobile`: Android Mobile POS Flutter app initialized.
- `apps/desktop`: Windows Admin Node Flutter app initialized.
- `packages/billing_engine`: Pure Dart calculation package scaffolded and passing tests.
- `packages/database`: Pure Dart Drift schema package scaffolded.
- `packages/sync_protocol`: Pure Dart network contracts and DTO package scaffolded.
- Root `analysis_options.yaml` and `.gitignore` added and verified.
