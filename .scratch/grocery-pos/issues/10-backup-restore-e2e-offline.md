# 10: Local Database Backup, Restore & End-to-End Offline Verification

**What to build:**
Automated scheduled SQLite database backups to local Windows directories, manual one-click export to removable USB storage, complete backup restoration flow, and full end-to-end multi-terminal simulation verifying that turning off the desktop does not block mobile cashier operations.

**Blocked by:**
09: Idempotent Sync Queue & Delta Inventory Reconciliation

**Status:**
ready-for-agent

**Acceptance Criteria:**
- [ ] Windows admin can trigger manual database backup and configure automated daily backups.
- [ ] Support for direct backup export to USB flash drives.
- [ ] Database restoration integrity checks verify table schemas before replacing the active database.
- [ ] End-to-end offline verification: cashiers complete sales while desktop server is killed; all pending sales sync cleanly once server restarts.

