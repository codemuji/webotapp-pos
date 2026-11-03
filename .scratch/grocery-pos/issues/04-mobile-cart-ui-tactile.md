# 04: Mobile POS Tactile Cart & Numpad Interaction

**What to build:**
The core cashier shopping cart interface in `apps/mobile` built according to Emil Kowalski's design engineering standards: responsive `scale(0.97)` tactile button feedback in 120ms (`Curves.easeOutCubic`), zero-layout-shift cart list with fixed cell heights, origin-anchored quantity popovers, numeric keypad for quick weight/quantity entry, and optimistic Riverpod cart state.

**Blocked by:**
02: Deterministic Pure Dart Billing Engine, 03: Drift SQLite Schema & In-Memory Persistence Harness

**Status:**
ready-for-agent

**Acceptance Criteria:**
- [ ] Cart item list renders with fixed-height rows and zero layout shifts when adding or removing items.
- [ ] All interactive buttons (increment, decrement, clear, checkout) implement tactile tap feedback (`scale(0.97)` in 120ms).
- [ ] Numpad modal enters with `scale(0.95)` to `1.0` and opacity fade (never from `scale(0)`).
- [ ] Cart totals update instantaneously (< 16ms) via Riverpod without full-screen rebuilds.
- [ ] Widget test suite verifies tactile button transforms and optimistic cart calculations.
