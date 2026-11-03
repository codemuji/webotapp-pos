# 02: Deterministic Pure Dart Billing Engine

**What to build:**
A standalone, pure Dart decimal calculation engine in `packages/billing_engine` responsible for computing item subtotals, unit pricing, item-level discounts, invoice-level discounts, tax breakdowns (GST brackets), and currency rounding without floating-point inaccuracies. Built completely test-first with unit tests covering edge cases.

**Blocked by:**
01: Monorepo Foundation & Workspace Setup

**Status:**
ready-for-agent

**Acceptance Criteria:**
- [ ] Decimal-safe currency calculations implemented (zero floating-point precision leaks).
- [ ] Support for percentage and fixed amount discounts at line-item and invoice levels.
- [ ] Configurable tax tiers (tax-inclusive and tax-exclusive modes).
- [ ] Mathematical rounding strategies conform to standard financial rounding rules.
- [ ] 100% test coverage with automated unit tests for zero amounts, 100% discount, fractional quantities, and multi-tier tax computation.
