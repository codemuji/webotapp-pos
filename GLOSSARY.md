# Grocery POS — Domain Glossary

This document is the authoritative domain vocabulary for Grocery POS. All specifications, models, code symbols, tickets, and user stories must use these terms consistently.

---

### Core Entities & Roles

- **Mobile POS Terminal (Terminal):** An Android handheld device operated by a cashier/employee for barcode scanning, cart manipulation, offline receipt generation, and bill sharing. Runs a local independent SQLite database.
- **Windows Admin Node (Admin Node / Desktop Node):** The central Windows desktop workstation located in the back-office or checkout counter. Runs the central SQLite database, Dart Shelf local HTTP synchronization server, catalog management, inventory ledger, and analytical dashboard.
- **Cashier / Employee:** A store worker authorized to operate a Mobile POS Terminal, authenticated via local hashed PIN code with role-based permission gates.
- **Store Administrator (Admin):** A privileged user with unrestricted access to the Windows Admin Node for managing catalog items, employees, pricing, inventory movements, and system backups.

### Transaction & Billing Domain

- **Invoice:** An immutable sales transaction record containing header metadata (invoice number, cashier ID, terminal ID, subtotal, tax amount, discount, total amount, timestamp, and payment method). Identified universally by an idempotent collision-free UUID.
- **Line Item (`InvoiceItem`):** An atomic snapshot entry of an item sold inside an invoice. *Crucial rule:* Line items store immutable point-in-time copies of `product_name`, `unit_price`, and `tax_amount` so subsequent product edits never alter historical sales data.
- **Billing Engine:** Pure Dart deterministic calculation engine that computes item subtotals, invoice discounts, GST/tax breakdowns, and currency rounding using decimal-safe monetary arithmetic (no raw floating-point calculation errors).
- **Payment Method:** The financial rail recorded for an invoice (`cash`, `upi_qr`, `card`, `credit`).

### Synchronization & Networking Domain

- **Local Wi-Fi Mesh / Intranet:** The physical or virtual local wireless network connecting Terminals to the Windows Admin Node without internet dependency.
- **QR Pairing Handshake:** The discovery and security bootstrap flow where a mobile terminal scans a dynamic QR code presented on the Windows Desktop. Transmits the local IP address, port, and temporary pairing credential/bearer token.
- **Sync Queue:** A persistent local SQLite queue on each Mobile Terminal containing unsynchronized invoices and item payloads with retry counters, timestamps, and delivery state (`pending`, `synced`, `failed`).
- **Sync Ack (`HTTP 200 ACK`):** Idempotent acknowledgment sent by the Windows Node to the Mobile Terminal upon receiving a transaction UUID. If the UUID was previously processed, the Desktop returns ACK without duplicate database insertion.
- **Delta Inventory Movement:** An incremental inventory change record (`+quantity` on restock/return, `-quantity` on sale). Mobile terminals never transmit absolute inventory counts; they only emit delta deductions upon invoice finalization, preventing offline stock overwrites.

### Storage & Platform

- **Drift Database:** Type-safe, reactive Dart abstraction layer over native SQLite (`drift` / `sqlite3`).
- **Shelf Sync Server:** Lightweight asynchronous HTTP daemon embedded directly inside the Flutter Windows Desktop application.
