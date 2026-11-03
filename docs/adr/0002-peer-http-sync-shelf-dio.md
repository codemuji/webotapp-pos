# ADR 0002: Peer-to-Desktop HTTP Synchronization via Shelf & Dio

## Context
Mobile POS terminals must synchronize finalized invoices, line items, and device status to the Windows Admin Node over the store's local Wi-Fi, and receive catalog and employee updates in return.

## Decision
We implement a lightweight local REST API on the Windows Desktop using `Dart Shelf` (`shelf`, `shelf_router`), paired with `Dio` on the Android Mobile app.
- Discovery & Pairing: Desktop displays a dynamic QR code containing its LAN IP, port, and a temporary pairing secret. Mobile terminal scans the QR code to register device identity and store bearer credentials in encrypted secure storage (`flutter_secure_storage`).
- Outgoing Sync Queue: Mobile app queues completed invoices in a local `sync_queue` table. Invoices are dispatched to `/api/v1/sync/invoices`.
- Idempotency & Acknowledgment: Each invoice carries a unique UUID v4. The desktop validates uniqueness against existing invoice records. If a duplicate UUID is received, it returns `HTTP 200 ACK` immediately without re-inserting. Upon ACK, mobile marks the item `synced`.

## Consequences
- **Positive:** No external server needed. High throughput over standard Wi-Fi router. Low resource footprint on Windows. Resilient to dropped packets with automatic retries.
- **Negative:** Dependent on local subnet connectivity between mobile devices and the desktop machine. Changing router IPs requires dynamic mDNS discovery or re-pairing scan.

