# 05: Mobile Barcode & QR Camera Scanner Integration

**What to build:**
Real-time camera barcode and QR code scanner integration in `apps/mobile` utilizing `mobile_scanner`. Supports EAN-13, UPC-A, and store custom QR formats with continuous scanning, instant duplicate item increment, audio chirp + haptic vibration confirmation, and manual text search fallback.

**Blocked by:**
04: Mobile POS Tactile Cart & Numpad Interaction

**Status:**
ready-for-agent

**Acceptance Criteria:**
- [ ] Camera scanner captures EAN-13, UPC-A, and QR codes at 60fps.
- [ ] Duplicate scan detection increments existing cart item quantity instantly without jarring UI animation.
- [ ] Haptic pulse and audio feedback trigger within 50ms of barcode detection.
- [ ] Manual search sheet allows immediate product lookup by name or SKU when barcodes are damaged.

