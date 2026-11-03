# ADR 0001: Offline-First Architecture with Drift SQLite

## Context
Small retail grocery stores frequently experience unreliable internet connections or local network drops. Recurring cloud subscriptions (Firebase, Supabase, hosted cloud databases) create unnecessary monthly overhead and introduce point-of-sale downtime whenever connectivity fails.

## Decision
We choose an offline-first architecture using native SQLite abstracted via **Drift (Dart)** on both Android (Mobile POS) and Windows (Desktop Admin).
- Every device maintains its own fully autonomous local database file.
- All transactional workflows (item lookup, cart management, subtotal/tax calculations, PDF invoice creation, and payment recording) occur 100% locally on device.
- Drift provides reactive streams, compile-time SQL query validation, and type-safe Dart classes.

## Consequences
- **Positive:** Zero dependency on cloud uptime. Zero monthly subscription costs. Transactions never fail due to network interruptions. Fast local query performance (< 5ms).
- **Negative:** Schema migrations must be managed carefully across distributed standalone devices. State synchronization must be handled explicitly peer-to-peer.
