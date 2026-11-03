# 04: Mobile POS Tactile Cart & Numpad Interaction

**What to build:**
The core cashier shopping cart interface in `apps/mobile` built according to Emil Kowalski's design engineering standards: responsive `scale(0.97)` tactile button feedback in 120ms (`Curves.easeOutCubic`), zero-layout-shift cart list with fixed cell heights, origin-anchored quantity popovers, numeric keypad for quick weight/quantity entry, and optimistic Riverpod cart state.

**Blocked by:**
02: Deterministic Pure Dart Billing Engine, 03: Drift SQLite Schema & In-Memory Persistence Harness

**Status:**
resolved

**Acceptance Criteria:**
- [x] Cart item list renders with fixed-height rows and zero layout shifts when adding or removing items.
- [x] All interactive buttons (increment, decrement, clear, checkout) implement tactile tap feedback (`scale(0.97)` in 120ms).
- [x] Numpad modal enters with `scale(0.95)` to `1.0` and opacity fade (never from `scale(0)`).
- [x] Cart totals update instantaneously (< 16ms) via Riverpod without full-screen rebuilds.
- [x] Widget test suite verifies tactile button transforms and optimistic cart calculations.

## Answer
Implemented Mobile POS Tactile Cart & Numpad UI in `apps/mobile`:
- `CartState` & `CartNotifier` in Riverpod providing optimistic, instantaneous cart mutations integrated with pure Dart `BillingEngine`.
- `TactileButton` implementing Emil Kowalski's micro-interaction standards: `scale(0.97)` active press feedback in 120ms (`Curves.easeOutCubic`) with a guaranteed 48x48dp minimum touch target.
- `CartScreen` & `_CartItemRow` with fixed 72dp cell heights for zero layout shifts during rapid continuous cashier item entries.
- `QuantityNumpadDialog` featuring asymmetric entrance animation starting at `scale(0.95)` with fade (never `scale(0)`), supporting decimal weights (e.g. `0.375 kg`).
- 14 comprehensive unit & widget tests in `apps/mobile/test/` passing 100% green.

