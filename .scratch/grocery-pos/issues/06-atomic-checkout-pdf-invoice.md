# 06: Atomic Checkout & Instant PDF / WhatsApp Bill Generation

**What to build:**
Complete offline checkout workflow: payment method selection (`cash`, `upi_qr`, `card`, `credit`), cash tender change calculation, atomic transaction commit to local Drift SQLite (invoice header + line item snapshots + sync queue entry), instantaneous PDF receipt generation (< 300ms), and native Android share / WhatsApp direct dispatch.

**Blocked by:**
04: Mobile POS Tactile Cart & Numpad Interaction, 05: Mobile Barcode & QR Camera Scanner Integration

**Status:**
resolved

**Acceptance Criteria:**
- [x] Atomic database transaction writes invoice and line items in a single operation.
- [x] Cash tender calculator instantly calculates change due upon numpad entry.
- [x] PDF receipt renders with clean thermal layout (58mm/80mm) and standard A4 invoice format.
- [x] Integration with `share_plus` exposes native WhatsApp, Bluetooth printer, and Android share sheet.
- [x] Successful checkout places the transaction into `sync_queue` with `pending` status.
