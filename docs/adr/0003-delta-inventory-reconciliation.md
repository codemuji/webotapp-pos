# ADR 0003: Delta Inventory Movements for Multi-Terminal Stock Consistency

## Context
Multiple offline mobile terminals may sell identical products concurrently while disconnected from the desktop server (e.g. Phone 1 sells 2 units, Phone 2 sells 3 units from an initial stock of 10). If mobile terminals push their local absolute remaining stock, the last terminal to sync will overwrite preceding sales, corrupting the inventory ledger.

## Decision
Mobile terminals must NEVER overwrite the central stock quantity with an absolute count. Instead:
- Mobile devices track and emit **Delta Inventory Movements** (e.g. `delta: -2`, `delta: -3`).
- The Windows Admin Node maintains the authoritative master inventory ledger.
- When transactions synchronize, the desktop applies delta adjustments sequentially to `inventory_movements` and recalculates current stock (`stock = initial - sum(deltas)`).
- On mobile terminals, displayed stock counts are explicitly treated as local cached estimates.

## Consequences
- **Positive:** Mathematically sound offline concurrency. Prevents lost sales updates and stock overwrites. Full audit trail of who sold what, when, and from which terminal.
- **Negative:** If a store is near zero stock, offline devices might temporarily oversell before resynchronizing.

