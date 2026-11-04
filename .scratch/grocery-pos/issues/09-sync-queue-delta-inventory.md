# 09: Idempotent Sync Queue & Delta Inventory Reconciliation

**What to build:**
Complete asynchronous data synchronization loop between Mobile Terminals and Windows Admin Node: Mobile background queue worker with exponential retry sending pending invoices to `/api/v1/sync/invoices`, desktop idempotent invoice ingestion by UUID returning `HTTP 200 ACK`, delta inventory ledger reconciliation, and product catalog synchronization from desktop to mobile.

**Blocked by:**
06: Atomic Checkout & Instant PDF / WhatsApp Bill Generation, 08: Embedded Shelf HTTP Server & QR Pairing Flow

**Status:**
resolved

**Acceptance Criteria:**
- [x] Mobile terminal sync worker drains `sync_queue` over local Wi-Fi when desktop is reachable.
- [x] Windows server checks UUID uniqueness before saving invoices; duplicate UUIDs receive `HTTP 200 ACK` without duplicate database records.
- [x] Central inventory updates via Delta Inventory Movements (`inventory_movements`), preventing overwrite bugs when multiple offline terminals sell the same SKU.
- [x] Mobile terminals pull updated product catalogs and prices upon sync completion.
- [x] Concurrency and retry integration tests verify zero lost sales and zero duplicates.
