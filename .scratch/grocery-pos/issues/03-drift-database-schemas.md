# 03: Drift SQLite Schema & In-Memory Persistence Harness

**What to build:**
Centralized Drift database package in `packages/database` defining schemas for `products`, `categories`, `employees`, `invoices`, `invoice_items`, `inventory_movements`, `devices`, and `sync_queue`. Includes DAOs, snapshot mapping, and in-memory test harness validating transactional atomic writes and point-in-time item immutability.

**Blocked by:**
01: Monorepo Foundation & Workspace Setup, 02: Deterministic Pure Dart Billing Engine

**Status:**
resolved

**Acceptance Criteria:**
- [x] Drift table definitions for products, categories, employees, invoices, invoice_items, inventory_movements, devices, and sync_queue.
- [x] Invoices store UUID v4 primary keys and enforce foreign key cascades where appropriate.
- [x] `invoice_items` captures frozen point-in-time values for product name, unit price, and tax amounts.
- [x] Drift code generation (`build_runner`) produces type-safe queries and DAOs.
- [x] In-memory SQLite unit test suite asserts atomic transaction commits and rollbacks on failure.

## Answer
Implemented the centralized Drift database package in `packages/database`:
- Table definitions for `Categories`, `Products`, `Employees`, `Invoices`, `InvoiceItems`, `InventoryMovements`, `SyncQueue`, and `Devices`.
- Configured foreign keys and cascade deletions with SQLite PRAGMA `foreign_keys = ON`.
- `recordCheckoutTransaction`: atomic multi-table commit and rollback on failure.
- `applyInventoryDelta`: delta movement logging and stock ledger reconciliation.
- `getPendingSyncItems`, `markSyncItemSuccess`, and `recordSyncItemFailure` for sync queue state transitions.
- 10 comprehensive unit tests in `packages/database/test/database_test.dart` passing 100% green.

