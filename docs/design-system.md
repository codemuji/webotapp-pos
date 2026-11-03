# Grocery POS — Design Engineering & Interaction Standards
*Codified from Emil Kowalski's Design Engineering Philosophy (`emil-design-eng`)*

---

## 1. Core Principles in a Point-of-Sale Environment

1. **Taste is Trained, Not Innate:** Software that handles rapid retail transactions must feel crisp, responsive, and trustworthy. Every micro-interaction communicates stability.
2. **Unseen Details Compound:** Cashiers scan hundreds of items per shift. Sub-millisecond tactile feedback, zero visual jitter, and instant cart updates compound into an effortless operator experience.
3. **Beauty is Leverage:** A modern, clean, dark/light optimized POS interface reduces cashier eye strain, speeds up scanning workflows, and inspires customer trust at checkout.

---

## 2. The POS Animation Decision Framework

Before adding any motion or transition to Grocery POS, evaluate through this strict matrix:

| Action / Frequency | Frequency Category | Decision | Rationale |
| :--- | :--- | :--- | :--- |
| **Barcode Scan Item Add** | 100+ times / shift | **No animation. Instant insertion.** | Cashiers need immediate confirmation. Any entering slide or bounce slows down continuous scanning. |
| **Numpad Digit Press** | 100+ times / shift | **No animation. Instant key feedback.** | Keypad must never lag or queue visual transitions. |
| **Button Tap / Primary Actions** | Tens of times / shift | **Tactile Active Press (`scale(0.97)` in 120ms)** | Gives instant physical sensation that the terminal registered the touch. |
| **Payment Dialog / Sheet** | Once per transaction | **Origin-aware or Sheet Transition (200ms `ease-out`)** | Smooth spatial consistency without blocking user decision speed. |
| **Checkout Success / Receipt Share** | Completion event | **Crisp checkmark state transition (180ms)** | Visual relief confirming transaction persistence and sync queuing. |

> **Rule:** Never animate keyboard-initiated actions or high-frequency barcode additions. UI animations must stay under **200ms**.

---

## 3. Tactile Component Guidelines

### Buttons & Pressables
- All actionable items (Add to Cart, Checkout, Delete Item, Numpad buttons) must implement an active tap state:
  - Down-scale: `scale(0.97)` with `120ms - 160ms` duration using custom ease-out curve (`cubic-bezier(0.23, 1, 0.32, 1)`).
  - Instant release: Snappy rebound without bouncy wobble.
  - Minimum touch target: `48 x 48 dp` for mobile touch surfaces; accessible for fast-paced finger taps.

### Modals, Popovers & Drawers
- **Never animate from `scale(0)`:** Popovers and dialogs enter from `scale(0.95)` with simultaneous opacity fade (`0 -> 1`) in `180ms`.
- **Origin-Aware Popovers:** Quantity adjusters and discount popovers anchor and scale outward from the specific line-item card that triggered them.
- **Asymmetric Timing:** Modal dismiss/cancel is faster (`140ms ease-out`) than modal presentation (`200ms ease-out`).

### Scanning Feedback & Perceived Speed
- **Audio + Haptic + Visual:** A barcode scan triggers a snappy haptic tick + high-frequency audio chirp (< 50ms) + immediate optimistic cart insertion.
- **Zero Layout Shifts:** Reserve line item heights and column widths in the cart list. Adding a line item must not cause adjacent items to jump or reflow.
- **Color Transitions:** Use subtle semantic accents (Emerald Green `#10B981` for active scan/success, Coral `#EF4444` for delete/remove, Indigo `#6366F1` for primary checkout).

---

## 4. Design Engineering Review Checklist

When writing or reviewing any UI widget in Mobile or Desktop:

| Before (Generic / Sluggish) | After (Emil Design Eng Standard) | Why |
| :--- | :--- | :--- |
| Animated list slide on barcode scan | Instant item insertion into cart list | Scanning requires instantaneous throughput |
| Default `ElevatedButton` without feedback | `scale(0.97)` tactile transform on tap down | Tactile confirmation prevents duplicate double-taps |
| Dialog popping from `scale(0)` | Fade + subtle scale from `0.95` to `1.0` | Natural physical emergence; avoids popping from nowhere |
| `Curves.easeIn` on menus | `Curves.easeOutCubic` (160ms - 200ms) | Ease-in feels sluggish; ease-out responds immediately |
| Long spinner waiting for SQLite | Optimistic UI update with background write | UI remains 60fps responsive; disk writes are asynchronous |

