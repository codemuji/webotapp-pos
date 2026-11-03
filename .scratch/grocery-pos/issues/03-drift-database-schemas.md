# 03: Drift SQLite Schema & In-Memory Persistence Harness

**What to build:**
Centralized Drift database package in `packages/database` defining schemas for `products`, `categories`, `employees`, `invoices`, `invoice_items`, `inventory_movements`, `devices`, and `sync_queue`. Includes DAOs, snapshot mapping, and in-memory test harness validating transactional atomic writes and point-in-time item immutability.

**Blocked by:**
01: Monorepo Foundation & Workspace Setup, 02: Deterministic Pure Dart Billing Engine

**Status:**
ready-for-agent

**Acceptance Criteria:**
- [ ] Drift table definitions for products, categories, employees, invoices, invoice_items, inventory_movements, devices, and sync_queue.
- [ ] Invoices store UUID v4 primary keys and enforce foreign key cascades where appropriate.
- [ ] `invoice_items` captures frozen point-in-time values for product name, unit price, and tax amounts.
- [ ] Drift code generation (`build_runner`) produces type-safe queries and DAOs.
- [ ] In-memory SQLite unit test suite asserts atomic transaction commits and rollbacks on failure.
