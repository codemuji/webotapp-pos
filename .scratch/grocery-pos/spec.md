# Specification: Grocery POS (Offline-First Multi-Terminal Retail System)

Status: ready-for-agent

---

## Problem Statement

Small grocery and retail store owners face a dilemma: existing Point of Sale (POS) software either requires constant, reliable internet connectivity and expensive monthly SaaS/cloud subscriptions, or consists of cumbersome legacy desktop systems that do not allow mobile cashier floor-scanning. When the internet connection drops or electricity fluctuates, billing stops, long checkout queues form, and sales are lost. Furthermore, existing local multi-device solutions suffer from database race conditions, duplicate sales numbers, and conflicting inventory records when multiple cashiers work concurrently.

## Solution

Grocery POS delivers an offline-first, dual-application point-of-sale ecosystem with zero cloud subscriptions or external API dependencies:
1. **Android Mobile POS Application:** Empowers cashiers to walk the floor or staff checkout counters, rapidly scan items (camera barcode/QR), adjust cart quantities with tactile feedback, calculate decimal-safe totals/taxes, generate instant PDF invoices, share digital bills via WhatsApp, and persist all transactions to local SQLite even if the desktop server is powered down.
2. **Windows Desktop Admin Application:** Acts as the central administrative and inventory hub, running an embedded asynchronous HTTP synchronization daemon (Dart Shelf). It coordinates product catalog distributions, maintains the authoritative inventory ledger using delta movement reconciliation, provides sales analytics, and offers automated local database backup/restore.
3. **Local Peer-to-Desktop Sync Protocol:** Connects mobile terminals to the Windows admin node over local Wi-Fi via QR-based pairing and idempotent UUID acknowledgments, guaranteeing that no transaction is lost or duplicated.
4. **Emil Kowalski Design Engineering Polish:** Zero animation delays on high-throughput scanning, responsive micro-scale button feedback (`scale(0.97)` in 120ms), origin-anchored popovers, and high-contrast, zero-layout-shift UI layouts built for demanding grocery store shifts.

---

## User Stories

### Authentication & Access Control
1. As a cashier, I want to log into my mobile terminal using a simple 4-to-6 digit PIN, so that I can quickly authenticate at the start of my shift without needing internet access.
2. As a cashier, I want to see my employee name and terminal ID displayed in the app header, so that I have visual confirmation of who is logged in.
3. As a store administrator, I want to create, update, and deactivate employee accounts with assigned roles (Admin, Cashier) on the Windows node, so that I control who can operate terminals and access administrative functions.
4. As a store administrator, I want employee credentials and permissions to sync to mobile terminals over local Wi-Fi, so that terminals stay up-to-date with current staff privileges.
5. As a store administrator, I want to restrict cashier permissions on mobile terminals (e.g., maximum manual discount limits, no deletion of historical invoices), so that shrinkage and unauthorized discounts are prevented.

### Product Catalog & Scanning
6. As a cashier, I want to point my mobile terminal camera at an item barcode (EAN-13, UPC-A, or custom store QR code) and have it instantly recognized, so that I can add items to the cart in less than 200 milliseconds.
7. As a cashier, I want continuous scanning capability with audio and haptic feedback, so that I can scan multiple grocery items in rapid succession without tapping the screen repeatedly.
8. As a cashier, I want scanning an already-added product to increment its quantity by 1 automatically, so that I don't create duplicate cart rows for the same product.
9. As a cashier, I want a fast, local full-text search fallback by product name or SKU, so that I can add items when barcodes are torn, smudged, or missing.
10. As a store administrator, I want to create, edit, and deactivate products with selling prices, purchase prices, categories, barcodes, and units of measurement on the Windows node, so that our catalog remains accurate.
11. As a store administrator, I want to generate and print standard thermal barcode/QR labels for loose produce and store-packaged items directly from the desktop, so that unscanned items can be labeled for quick counter checkout.

### Shopping Cart & Billing Calculations
12. As a cashier, I want to see a clean, scrollable cart list with fixed row heights and zero layout shifts, so that reading items and totals is effortless.
13. As a cashier, I want tactile, responsive quantity adjuster buttons with immediate `scale(0.97)` tap feedback, so that I know my tap was registered without second-guessing.
14. As a cashier, I want to hold-to-delete an item or swipe with momentum dismissal, so that removing accidentally scanned items is quick and intuitive.
15. As a cashier, I want to apply allowable line-item or invoice-level percentage/fixed discounts, so that I can honor store promotions and customer deals.
16. As a cashier, I want tax calculations (e.g., GST tiers) to be computed accurately using decimal arithmetic, so that rounding errors and fractional penny discrepancies never occur.
17. As a cashier, I want to clearly view the subtotal, total discount, tax amount, and final rounded payable amount in prominent, high-contrast typography, so that customers can clearly see their total bill.

### Checkout, Invoicing & Digital Bill Sharing
18. As a cashier, I want to select a payment method (`cash`, `upi_qr`, `card`, `credit`) with one tap, so that I can finalize the sale without navigating complex dialogs.
19. As a cashier, I want entering cash tender to instantly calculate change due, so that I never make mental math errors when handing change to customers.
20. As a cashier, I want the system to generate a unique, collision-free UUID and sequential invoice number upon checkout confirmation, so that the order is permanently identifiable.
21. As a cashier, I want the invoice and line items to be committed atomically to local SQLite before any external communication is attempted, so that sales are never lost if the app or device battery dies.
22. As a cashier, I want line items in the invoice to record point-in-time snapshots of product names, barcodes, and prices, so that future price updates in the catalog never rewrite historical sales.
23. As a cashier, I want a formatted PDF receipt to be generated instantly (< 300ms) with thermal receipt and A4 layout options, so that customers can receive an itemized bill.
24. As a cashier, I want to share the digital invoice directly to the customer's WhatsApp or via native Android share sheets with one tap, so that paper receipt printing costs can be eliminated.
25. As a cashier, I want to reprint or re-share any past invoice from the local invoice history tab, so that customer inquiries and return requests can be verified.

### Local Network Synchronization & Device Pairing
26. As a cashier, I want to pair a new mobile terminal by scanning a QR code displayed on the Windows desktop, so that I don't have to manually type IP addresses, port numbers, or network tokens.
27. As a cashier, I want completed invoices to automatically enter a local sync queue and be dispatched to the desktop in the background, so that I can continue scanning the next customer's basket immediately.
28. As a cashier, I want the terminal to display a subtle, non-intrusive status pill indicating connection state (`Connected`, `Offline`, `3 Invoices Pending Sync`), so that I always know sync health at a glance.
29. As a cashier, I want the mobile terminal to continue functioning 100% normally if the Windows desktop is turned off or restarting, so that checkout lanes never stop.
30. As a store administrator, I want the desktop HTTP server to enforce idempotent transaction ingestion, so that repeated sync retries or network hiccups never insert duplicate invoices or revenue.
31. As a store administrator, I want the desktop to acknowledge synced invoices with `HTTP 200 ACK`, so that mobile terminals safely transition queue items from `pending` to `synced`.
32. As a store administrator, I want catalog updates made on Windows to be pulled by mobile terminals automatically upon reconnecting, so that terminals always possess fresh pricing.

### Central Administration, Inventory & Reporting
33. As a store administrator, I want an executive dashboard displaying today's total revenue, order count, average basket size, employee sales breakdown, and payment distribution, so that I have a live pulse on store performance.
34. As a store administrator, I want stock levels to adjust via **Delta Inventory Movements** rather than absolute overwrites, so that concurrent sales from multiple offline mobile terminals reconcile accurately without data loss.
35. As a store administrator, I want to view a real-time low-stock alert dashboard with configurable thresholds, so that fast-moving grocery items can be reordered in time.
36. As a store administrator, I want to log manual inventory adjustments (breakage, supplier delivery, stock takes) with reason codes and employee signatures, so that inventory shrink is auditable.
37. As a store administrator, I want to filter and search the master transaction log by date, employee, payment type, or invoice number on Windows, so that audits and reconciliations take seconds.
38. As a store administrator, I want to create automated daily database backups to local storage and perform one-click USB exports, so that store data is safely preserved without cloud hosting costs.
39. As a store administrator, I want to export sales and inventory reports to Excel, CSV, and PDF formats, so that my accountant and tax consultants have clean financial records.

---

## Implementation Decisions

### Monorepo & Project Structure
- Architecture: Flutter monorepo with clean separation of concerns:
  - `apps/mobile`: Mobile POS Application (Android)
  - `apps/desktop`: Desktop Admin Application (Windows)
  - `packages/billing_engine`: Pure Dart calculation package (tax tiers, discount math, currency rounding, decimal precision)
  - `packages/database`: Drift SQLite database definitions, migrations, tables, DAOs
  - `packages/sync_protocol`: Shared DTOs, JSON serialization, API contracts, pairing token schemas
- Pure Dart packages (`billing_engine`, `sync_protocol`) have zero Flutter UI dependencies, enabling maximum unit test speed and test-driven development (`/tdd`).

### Database & Persistence Layer
- SQLite with **Drift**: Type-safe Dart API, reactive streams, zero raw SQL string errors.
- Schema integrity:
  - `invoices.id` uses UUID v4 generated on the mobile terminal.
  - `invoice_items` stores frozen snapshots: `product_id`, `product_name`, `barcode`, `quantity`, `unit_price`, `discount`, `tax_amount`, `line_total`.
  - `sync_queue`: `id`, `transaction_id`, `operation`, `status` (`pending`, `synced`, `failed`), `retry_count`, `last_error`, `created_at`, `updated_at`.
  - `inventory_movements`: Immutable log of deltas (`reference_id`, `product_id`, `delta_quantity`, `reason`, `created_at`).

### Billing Calculation Seam
- Decimal monetary math: Monetary amounts stored as integer cents/paisa or standard `Decimal` representation to avoid floating-point rounding drifts (e.g., `0.1 + 0.2 != 0.3`).
- Single calculation seam: `BillingEngine.calculate(CartDraft, StoreTaxConfig) -> CalculationResult`.

### Networking & Sync Architecture
- Windows node embeds `shelf` and `shelf_router` listening on a configurable local port (default: 8085).
- Mobile node uses `dio` with exponential backoff retry interceptor and offline queue drainer.
- Pairing QR code payload: `JSON { "ip": "192.168.1.50", "port": 8085, "pairing_token": "...", "expires_at": "..." }`.
- Tokens saved to `flutter_secure_storage` on mobile.

### Interaction & Design Engineering Standards (Emil Kowalski)
- Touch targets: Minimum 48x48dp.
- Press feedback: `scale(0.97)` on tap-down with `120ms - 160ms` duration (`Curves.easeOutCubic`).
- No entering/exiting animations on high-frequency barcode scan inserts (instant 0ms update to maintain 60fps throughput).
- Modals scale from `0.95` with opacity, never from `0.0`.
- Asymmetric dialog timing: 200ms enter, 140ms exit.

---

## Testing Decisions

### What Makes a Good Test
- Tests only assert external observable behavior and domain invariants, never internal implementation details or private widget states.
- 100% of monetary and billing calculations must be verified with automated edge-case unit tests (zero-amount items, 100% discount, fractional quantities, GST slabs).
- Sync idempotency must be proven with concurrency tests (sending identical invoice UUIDs repeatedly to ensure only 1 record is created).
- Database migrations and snapshot consistency must be verified with Drift in-memory test harnesses.

### Testing Seams
1. **Billing Engine Seam:** Unit tests over `packages/billing_engine` using standard `test`.
2. **Database DAO Seam:** In-memory SQLite tests over `packages/database` validating cascade behavior, snapshot immutability, and queue state transitions.
3. **Sync Engine Seam:** Integration tests running Shelf server and Dio client in memory, simulating network drops, retries, and duplicate UUID transmissions.
4. **Widget Interaction Seam:** Flutter widget tests verifying tap-down tactile scales, optimistic cart insertion, and PIN authentication keypad.

---

## Out of Scope

- Multi-branch cloud replication across different geographical cities.
- Automated payment gateway terminal integration (credit card chip-and-pin hardware).
- Customer loyalty point schemes and marketing SMS blasts.
- AI-based inventory restocking predictions.

---

## Further Notes

- The system uses standard local Wi-Fi. If a store does not have a router, a mobile terminal's Wi-Fi Hotspot can be used as the local subnet, with the Windows laptop connecting to the hotspot.
- Invoices are legally compliant point-of-sale receipts with configurable tax registration (GSTIN), store name, and sequential numbering series.
