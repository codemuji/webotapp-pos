# 08: Embedded Shelf HTTP Server & QR Pairing Flow

**What to build:**
Embedded Dart Shelf HTTP daemon running inside `apps/desktop` on local port 8085. Generates a dynamic pairing QR code (LAN IP, port, ephemeral pairing token). Mobile POS terminal camera scans the pairing code to negotiate secure device registration and stores bearer token in `flutter_secure_storage`.

**Blocked by:**
03: Drift SQLite Schema & In-Memory Persistence Harness, 07: Windows Desktop Admin Dashboard & Catalog Management

**Status:**
resolved

**Acceptance Criteria:**
- [x] Desktop app starts and stops Shelf HTTP server bound to local network interface.
- [x] Desktop UI displays pairing QR code with live server status, host IP, and active port.
- [x] Mobile terminal pairing screen scans QR code, validates handshake, and receives bearer token.
- [x] Pairing tokens securely saved in `flutter_secure_storage` on mobile.
- [x] Server rejects unauthenticated HTTP requests from unpaired devices.
