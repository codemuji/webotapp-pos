# 02: Deterministic Pure Dart Billing Engine

**What to build:**
A standalone, pure Dart decimal calculation engine in `packages/billing_engine` responsible for computing item subtotals, unit pricing, item-level discounts, invoice-level discounts, tax breakdowns (GST brackets), and currency rounding without floating-point inaccuracies. Built completely test-first with unit tests covering edge cases.

**Blocked by:**
01: Monorepo Foundation & Workspace Setup

**Status:**
resolved

**Acceptance Criteria:**
- [x] Decimal-safe currency calculations implemented (zero floating-point precision leaks).
- [x] Support for percentage and fixed amount discounts at line-item and invoice levels.
- [x] Configurable tax tiers (tax-inclusive and tax-exclusive modes).
- [x] Mathematical rounding strategies conform to standard financial rounding rules.
- [x] 100% test coverage with automated unit tests for zero amounts, 100% discount, fractional quantities, and multi-tier tax computation.

## Answer
Implemented pure Dart `BillingEngine` via strict test-driven development (`/tdd`):
- `CartItemInput`, `Discount` (percentage/fixed), `TaxMode` (exclusive/inclusive), and `RoundingStrategy` (none, toNearestInteger).
- Subtotals, line discounts, invoice-level discounts, GST rate brackets, and half-up financial rounding.
- 15 comprehensive unit tests in `packages/billing_engine/test/billing_engine_test.dart` passing 100% green.

