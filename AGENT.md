# Grocery POS — System Architecture & Technical Specification

**Document Version:** 1.0  
**Date:** 3 November 2026  
**Platform:** Android + Windows  
**Architecture:** Offline-first, local database, peer-to-desktop synchronization  
**Development Framework:** Flutter + Dart

---

## Agent skills

### Issue tracker

Issues are tracked as local markdown files under `.scratch/grocery-pos/issues/`. See [issue-tracker.md](file:///c:/Users/codemuji/StudioProjects/grocery-pos/docs/agents/issue-tracker.md).

### Triage labels

Canonical 5-role triage vocabulary mapped for local tracking. See [triage-labels.md](file:///c:/Users/codemuji/StudioProjects/grocery-pos/docs/agents/triage-labels.md).

### Domain docs

Single-context repository layout with root [GLOSSARY.md](file:///c:/Users/codemuji/StudioProjects/grocery-pos/GLOSSARY.md) and [docs/adr/](file:///c:/Users/codemuji/StudioProjects/grocery-pos/docs/adr/). See [domain.md](file:///c:/Users/codemuji/StudioProjects/grocery-pos/docs/agents/domain.md).

### Design Engineering Standards

UI polish, animation decisions, and tactile component interaction craft codified from Emil Kowalski's philosophy. See [design-system.md](file:///c:/Users/codemuji/StudioProjects/grocery-pos/docs/design-system.md).

---

## 1. Project Overview

Grocery POS is an offline-first point-of-sale system consisting of two independent applications:

1. **Mobile POS Application (Android):** Used by employees to scan products, manage shopping carts, generate invoices, and share bills with customers.
2. **Desktop Admin Application (Windows):** Used by store administrators to manage products, employees, inventory, sales reports, and transaction history.

Both applications operate independently without requiring an internet connection or cloud infrastructure.

The mobile application performs all billing operations locally. The Windows application acts as the central administration and transaction-management system.

The two applications communicate over a local network whenever synchronization is available.

### Primary Objectives

- Eliminate recurring cloud hosting costs.
- Support completely offline billing.
- Allow multiple employees to generate invoices simultaneously.
- Maintain centralized transaction history on Windows.
- Synchronize transactions reliably without duplicates.
- Keep the system simple enough for small grocery stores.

---

## 2. System Architecture

### 2.1 High-Level Architecture

The system follows an offline-first client-server architecture.

**Android Mobile Application**
- Local SQLite database.
- Product catalog cache.
- Employee authentication.
- Barcode and QR scanning.
- Shopping cart management.
- Billing engine.
- PDF invoice generation.
- Local transaction history.
- Outgoing synchronization queue.

**Windows Desktop Application**
- Local SQLite database.
- Product management.
- Employee management.
- Inventory management.
- Transaction management.
- Sales analytics.
- Local HTTP synchronization server.
- Backup and restoration.

**Communication Layer**
- Local Wi-Fi network.
- HTTP-based synchronization API.
- QR-based device pairing.
- Transaction acknowledgement.
- Automatic retry mechanism.

No external API, cloud database, Firebase, Supabase, or continuously hosted backend is required.

### 2.2 Architectural Diagram

```text
                 GROCERY STORE
                       |
                 LOCAL WI-FI
                       |
             WINDOWS DESKTOP APP
             --------------------
             Admin Dashboard
             Product Management
             Employee Management
             Sales Reports
             Central Database
             Local API Server
                       |
               HTTP Synchronization
                       |
          +------------+------------+
          |            |            |
       MOBILE 1     MOBILE 2     MOBILE 3
          |            |            |
       SQLite       SQLite       SQLite
          |            |            |
       Billing      Billing      Billing
       Engine       Engine       Engine
          |            |            |
       Invoice      Invoice      Invoice
       History      History      History
          |            |            |
       Sync Queue   Sync Queue   Sync Queue
```

Each mobile device maintains its own database and can continue working if the desktop is switched off.

---

## 3. Mobile Application — Employee POS

### 3.1 Core Modules

**A. Authentication**
- Employee login.
- PIN-based authentication.
- Employee identification.
- Role-based permissions.
- Device registration.

**B. Product Scanner**
- Camera-based QR scanning.
- EAN-13 and UPC barcode support.
- Custom store-generated QR codes.
- Continuous scanning.
- Duplicate scan handling.
- Manual product search.

**C. Shopping Cart**
- Add and remove products.
- Update quantities.
- Change quantities manually.
- Calculate subtotal.
- Apply permitted discounts.
- Calculate configured taxes.
- Display final payable amount.

**D. Invoice Generation**
- Generate unique transaction ID.
- Generate invoice number.
- Store invoice and invoice items locally.
- Generate PDF invoice.
- Display invoice preview.
- Share invoice through Android share functionality.
- Support WhatsApp sharing through the installed application.

**E. Transaction History**
- View previous transactions.
- Search invoices.
- View invoice details.
- Re-share invoices.
- Display synchronization status.

**F. Synchronization**
- Pending transaction queue.
- Automatic synchronization attempts.
- Manual synchronization.
- Retry failed transactions.
- Display sync history.

### 3.2 Mobile Billing Workflow

1. Employee logs in.
2. Employee opens the scanner.
3. Products are scanned.
4. Product details are retrieved from SQLite.
5. Products are added to the cart.
6. Employee confirms quantities.
7. Customer information is entered optionally.
8. Payment method is selected.
9. Billing engine calculates the final amount.
10. Invoice is generated.
11. Transaction is committed to the local database.
12. PDF invoice is generated.
13. Employee shares the invoice with the customer.
14. Transaction enters the synchronization queue.

**Important:** Invoice creation and local persistence must not depend on desktop availability or synchronization success.

---

## 4. Windows Application — Admin POS

### 4.1 Core Modules

**A. Dashboard**
- Total sales today.
- Total sales this month.
- Total transactions.
- Average transaction value.
- Employee-wise sales.
- Payment method breakdown.

**B. Product Management**
- Add products.
- Edit product information.
- Delete or deactivate products.
- Set selling prices.
- Set purchase prices.
- Assign product categories.
- Register barcodes and QR codes.
- Generate printable product labels.

**C. Employee Management**
- Create employee accounts.
- Assign roles.
- Activate/deactivate employees.
- View employee transaction history.
- Track employee-wise sales.

**D. Inventory Management**
- View current stock.
- Update stock quantities.
- Record stock additions.
- Record stock adjustments.
- Configure low-stock thresholds.
- View inventory movement history.

**E. Transaction Management**
- View synchronized transactions.
- Filter by date.
- Filter by employee.
- Search by invoice number.
- View invoice details.
- Export transaction reports.
- Print invoices.

**F. Synchronization Management**
- View registered devices.
- View device connection status.
- View last synchronization time.
- View received transactions.
- View synchronization errors.
- Reconcile failed transactions.

**G. Backup Management**
- Automatic local backups.
- Manual database backups.
- Restore previous backups.
- Export reports to CSV, Excel and PDF.

---

## 5. Database Architecture

Use SQLite with Drift as the primary database abstraction.

Both applications maintain independent SQLite databases.

### 5.1 Core Tables

| Table | Responsibility |
|---|---|
| products | Product catalog |
| categories | Product categories |
| employees | Employee accounts |
| customers | Customer information |
| invoices | Invoice headers |
| invoice_items | Invoice line items |
| inventory | Current stock |
| inventory_movements | Stock adjustments |
| devices | Registered mobile devices |
| sync_queue | Pending synchronization |
| sync_logs | Synchronization history |
| app_settings | Store configuration |

### 5.2 Products

```sql
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    barcode TEXT UNIQUE,
    sku TEXT,
    category_id TEXT,
    selling_price REAL NOT NULL,
    purchase_price REAL,
    stock_quantity REAL DEFAULT 0,
    unit TEXT DEFAULT 'pcs',
    is_active INTEGER DEFAULT 1,
    updated_at TEXT NOT NULL
);
```

### 5.3 Invoices

```sql
CREATE TABLE invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT NOT NULL,
    device_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    customer_id TEXT,
    subtotal REAL NOT NULL,
    discount REAL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    total_amount REAL NOT NULL,
    payment_method TEXT NOT NULL,
    created_at TEXT NOT NULL,
    sync_status TEXT DEFAULT 'pending'
);
```

### 5.4 Invoice Items

```sql
CREATE TABLE invoice_items (
    id TEXT PRIMARY KEY,
    invoice_id TEXT NOT NULL,
    product_id TEXT,
    product_name TEXT NOT NULL,
    barcode TEXT,
    quantity REAL NOT NULL,
    unit_price REAL NOT NULL,
    discount REAL DEFAULT 0,
    tax_amount REAL DEFAULT 0,
    line_total REAL NOT NULL
);
```

Historical product names and prices must be stored in invoice items. Old invoices must never change when the current product catalog is updated.

### 5.5 Synchronization Queue

```sql
CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    last_error TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

Use UUIDs for transaction identifiers.

Invoice numbers should have a separate numbering strategy. For multiple offline devices, consider device-specific invoice series and confirm the required statutory numbering rules with the store's accountant.

---

## 6. Synchronization Architecture

### 6.1 Primary Communication Method

Use local Wi-Fi and HTTP communication.

The Windows application runs a lightweight local HTTP server using Dart Shelf.

The Android application connects to the Windows application through the local network.

No internet connection is required.

### 6.2 Device Pairing

Recommended pairing procedure:

1. Windows application starts its synchronization server.
2. Desktop displays a pairing QR code.
3. Employee opens the mobile application.
4. Employee scans the pairing QR code.
5. Mobile extracts the desktop connection information and pairing credentials.
6. Device is registered with the desktop.
7. Connection is established.

The QR code should contain a pairing token or a short-lived pairing credential, not permanent administrator credentials.

### 6.3 Synchronization Direction

| Data | Direction |
|---|---|
| Products | Windows → Mobile |
| Product updates | Windows → Mobile |
| Categories | Windows → Mobile |
| Employee accounts and permissions | Windows → Mobile |
| Completed invoices | Mobile → Windows |
| Invoice items | Mobile → Windows |
| Device registration | Mobile ↔ Windows |
| Sync acknowledgement | Windows → Mobile |

### 6.4 Transaction Synchronization Workflow

```text
EMPLOYEE COMPLETES BILL
          |
          v
SAVE IN MOBILE SQLITE
          |
          v
ADD TO SYNC QUEUE
          |
          v
IS DESKTOP AVAILABLE?
       /       \
     NO         YES
     |           |
     v           v
REMAIN       SEND TRANSACTION
PENDING           |
     |            v
     |       DESKTOP VALIDATES
     |            |
     |            v
     |       CHECK DUPLICATE ID
     |            |
     |            v
     |       SAVE TRANSACTION
     |            |
     |            v
     |       SEND ACKNOWLEDGEMENT
     |            |
     v            v
  RETRY       MARK AS SYNCED
```

### 6.5 Duplicate Prevention

The Windows application must check transaction UUIDs before inserting transactions.

If the same transaction is received twice, the desktop should acknowledge the existing transaction instead of creating a duplicate.

Never delete the mobile transaction simply because it was transmitted. Retain the original transaction locally.

### 6.6 Network Discovery

Recommended implementation:

- Initial pairing through QR code.
- Store the paired desktop address securely.
- Use mDNS discovery where supported.
- Provide manual reconnection as a fallback.
- Handle desktop IP changes.

The desktop should display its server status and local network address.

---

## 7. Billing Engine

The billing engine should be implemented as a reusable Dart package.

It should handle:

- Product price retrieval.
- Quantity calculations.
- Item-level discounts.
- Invoice-level discounts.
- Tax calculations.
- Rounding.
- Subtotal and final total.
- Invoice validation.

Use decimal-safe monetary calculations rather than relying on unrestricted floating-point arithmetic.

All invoice calculations happen on the mobile device.

The desktop stores and reports the finalized transaction values.

GST configuration, HSN codes, tax-inclusive versus tax-exclusive prices, and invoice formatting should be configurable based on the store's requirements.

---

## 8. Technology Stack

| Component | Technology |
|---|---|
| Mobile application | Flutter |
| Desktop application | Flutter Windows |
| Language | Dart |
| Local database | SQLite |
| Database abstraction | Drift |
| State management | Riverpod |
| Barcode scanner | mobile_scanner |
| HTTP server | Dart Shelf |
| HTTP client | Dio |
| Device discovery | mDNS |
| Invoice generation | pdf |
| Invoice sharing | share_plus |
| Printing | printing |
| Secure storage | flutter_secure_storage |
| Unique identifiers | UUID |
| Logging | Dart logging |

All dependencies should be reviewed for Android and Windows compatibility before implementation.

---

## 9. Security and Reliability

Security requirements:

- Employee authentication.
- Role-based access control.
- Password/PIN hashing.
- Secure device pairing.
- Authentication for every synchronization request.
- Protected local API endpoints.
- Database backup protection.
- No unrestricted access to the desktop database.

Reliability requirements:

- Atomic invoice creation.
- Automatic synchronization retries.
- Transaction UUID validation.
- Database integrity checks.
- Application crash recovery.
- Failed synchronization logging.
- Backup and restore functionality.

The Windows synchronization server should only accept connections from authorized paired devices. Use encrypted local transport where practical, with certificate validation or another properly designed local authentication mechanism.

---

## 10. Inventory Consistency

An important architectural constraint is that multiple mobile devices may operate independently.

For example:

- Phone 1 sells 2 units of Maggi.
- Phone 2 sells 3 units of Maggi.
- Both phones were offline.
- The desktop originally had 10 units.

When both phones reconnect, the desktop must process both inventory movements.

Do not overwrite the desktop's stock quantity with the stock quantity stored on an individual phone.

Instead, use transaction-based inventory movements and reconcile them centrally.

The desktop should maintain the authoritative consolidated inventory record.

If employees are operating offline, the displayed stock on their phones must be treated as an estimate until synchronization occurs.

---

## 11. Backup and Data Recovery

Because the system has no cloud infrastructure, backup is essential.

Recommended backup features:

- Automatic daily desktop database backup.
- Manual backup option.
- USB backup support.
- Backup restoration.
- Exportable transaction reports.
- Optional encrypted external backup.

The mobile application should also preserve pending transactions until they have been safely synchronized and backed up.

---

## 12. Development Roadmap

### Phase 1 — Foundation
- Create Flutter monorepo.
- Configure shared packages.
- Implement database schemas.
- Implement product and employee models.
- Build basic authentication.
- Create desktop and mobile navigation.

### Phase 2 — Mobile Billing
- Implement barcode and QR scanning.
- Implement product lookup.
- Build shopping cart.
- Implement billing engine.
- Generate PDF invoices.
- Implement local transaction history.
- Test completely offline.

### Phase 3 — Desktop Administration
- Build admin dashboard.
- Implement product management.
- Implement employee management.
- Implement transaction history.
- Implement inventory management.
- Implement sales reports.

### Phase 4 — Synchronization
- Implement Windows local HTTP server.
- Implement QR-based device pairing.
- Implement mobile sync queue.
- Implement transaction upload.
- Implement product catalog download.
- Implement acknowledgement and retry logic.
- Test multiple mobile devices.

### Phase 5 — Production Readiness
- Printer integration.
- Backup and restore.
- Security testing.
- Performance testing.
- Offline recovery testing.
- Real grocery store pilot.
- Installer and application packaging.

---

## 13. MVP Acceptance Criteria

The first production-ready MVP should satisfy the following:

1. Employee can log in without internet.
2. Employee can scan grocery products.
3. Employee can generate a complete bill offline.
4. Employee can generate and share PDF invoices.
5. Transactions remain stored locally.
6. Desktop can be switched off without interrupting billing.
7. Transactions automatically synchronize when the desktop is available.
8. Multiple phones can connect to one desktop.
9. Duplicate transactions are prevented.
10. Admin can view consolidated transaction history.
11. Admin can manage products and employees.
12. Desktop data can be backed up and restored.

---

## 14. Architectural Decisions

| Decision | Selected approach |
|---|---|
| Application architecture | Offline-first |
| Mobile billing | Fully local |
| Desktop administration | Fully local |
| Database | Independent SQLite databases |
| Mobile-to-desktop communication | Local Wi-Fi |
| Synchronization server | Windows application |
| Device pairing | QR code |
| Transaction synchronization | Asynchronous |
| Internet dependency | None for core functionality |
| Cloud hosting | Not required |
| Billing calculations | Mobile only |
| Transaction consolidation | Windows |

---

## 15. Future Enhancements

These features are outside the initial MVP:

- Multi-branch store management.
- Cloud backup.
- Advanced inventory forecasting.
- Expiry-date notifications.
- Supplier and purchase management.
- Customer purchase history.
- Loyalty points.
- Advanced financial reporting.
- Additional platform support.

**Final Product Vision**

Build a reliable, affordable, offline-first grocery POS ecosystem that enables small retailers to manage billing, employees, products, inventory and sales without depending on cloud subscriptions or continuous internet connectivity.
