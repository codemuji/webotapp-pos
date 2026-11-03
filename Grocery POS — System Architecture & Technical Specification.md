# **Grocery POS — System Architecture & Technical Specification**

# **Document Specification Overview**

| Metadata Field | Specification Details |
| :---- | :---- |
| **Document Version** | 1.0 |
| **Date** | 3 November 2026 |
| **Target Platforms** | Android (Mobile) \+ Windows (Desktop) |
| **Architecture Pattern** | Offline-first, local database, peer-to-desktop synchronization |
| **Development Stack** | Flutter \+ Dart (Cross-Platform Monorepo) |

# **1\. Project Overview**

Grocery POS is an offline-first point-of-sale system consisting of two independent applications:

1. Mobile POS Application (Android): Used by store employees to scan products, manage shopping carts, generate invoices, and share digital bills with customers.  
2. Desktop Admin Application (Windows): Used by store administrators to manage products, employees, stock inventory, sales reports, and central transaction history.

Both applications operate independently without requiring an active internet connection or external cloud infrastructure. The mobile application performs all billing operations locally, while the Windows application acts as the central administration and transaction-management engine. The two applications communicate over a local wireless network whenever peer synchronization is available.

## **Primary Objectives**

* Eliminate recurring expenses: Zero reliance on cloud hosting, SaaS subscriptions, or database server costs.  
* Support 100% offline billing: Counter transactions run continuously regardless of Wi-Fi or internet availability.  
* Concurrent employee billing: Allow multiple employees to generate invoices simultaneously on independent devices.  
* Centralized audit trail: Maintain complete transaction history on the local Windows desktop system.  
* Reliable synchronization: Idempotent, transaction-safe synchronization without data duplication.  
* Operational simplicity: Frictionless workflow optimized for fast-paced small grocery environments.

# **2\. System Architecture**

# **2.1 High-Level Architecture**

The system follows an offline-first client-server architecture operating across a Local Area Network (LAN).

## **Android Mobile Application**

* Local SQLite database (Drift abstraction).  
* Product catalog cache & local search engine.  
* Employee authentication & PIN handling.  
* Camera-based Barcode and QR code scanning.  
* Shopping cart and discount calculation engine.  
* PDF invoice renderer & native WhatsApp/Share integration.  
* Local transaction history queue.  
* Outgoing HTTP synchronization worker.

## **Windows Desktop Application**

* Central SQLite master database.  
* Product, inventory, and employee administration modules.  
* Transaction management & analytical dashboards.  
* Local HTTP synchronization server (Dart Shelf).  
* Automated database backup and restoration engine.

## **Communication Layer**

* Local Wi-Fi network (TCP/IP).  
* HTTP RESTful synchronization API.  
* QR code device pairing and token verification.  
* Transaction acknowledgment and queue processing.

# **2.2 Architectural Topology**

```
                  +-----------------------------------+
                  |       WINDOWS DESKTOP APP         |
                  |  - Admin Dashboard                |
                  |  - Product & Stock Management     |
                  |  - Employee Management            |
                  |  - Central SQLite Database        |
                  |  - Local HTTP Synchronization API |
                  +-----------------------------------+
                                    ^
                                    |
                 Local Wi-Fi Network (HTTP Synchronization)
                                    |
       +----------------------------+----------------------------+
       |                            |                            |
+--------------+             +--------------+             +--------------+
|   MOBILE 1   |             |   MOBILE 2   |             |   MOBILE 3   |
| (SQLite DB)  |             | (SQLite DB)  |             | (SQLite DB)  |
| - POS Scan   |             | - POS Scan   |             | - POS Scan   |
| - Billing    |             | - Billing    |             | - Billing    |
| - Sync Queue |             | - Sync Queue |             | - Sync Queue |
+--------------+             +--------------+             +--------------+
```

# **3\. Mobile Application — Employee POS**

# **3.1 Core Modules**

## **A. Authentication**

* Employee login using PIN-based security.  
* Role-based feature restriction.  
* Unique mobile device registration tracking.

## **B. Product Scanner**

* Continuous camera scanning supporting EAN-13, UPC-A, and custom QR formats.  
* Duplicate scan detection and rapid item increment.  
* Fallback manual text/SKU product search.

## **C. Shopping Cart & Billing**

* Item addition, deletion, and manual quantity adjustments.  
* Subtotal calculation with item-level and invoice-level discount overrides.  
* Automated tax (GST) calculations based on store parameters.

## **D. Invoice Generation**

* Generation of collision-free UUID transaction identifiers.  
* PDF invoice rendering with print preview and native share hooks (WhatsApp, Email, Bluetooth printing).

## **E. Sync Queue Manager**

* Local SQLite queuing for pending transactions.  
* Background retries with status monitoring (Pending, Synced, Error).

# **3.2 Mobile Billing Workflow**

```
[Employee Login] -> [Open Camera Scanner] -> [Scan Product Barcode/QR]
                                                     |
                                                     v
[Commit Transaction to SQLite] <- [Confirm Payment] <- [Retrieve Item from Local DB]
              |
              +----> [Generate PDF Invoice & Share via WhatsApp]
              |
              +----> [Push to Local Sync Queue] -> [Attempt HTTP Sync to Desktop]
```

# **4\. Windows Application — Admin POS**

# **4.1 Core Modules**

## **A. Executive Dashboard**

* Real-time metrics: Today's sales, monthly revenue, total transactions, average order value, payment method breakdown, and top-selling items.

## **B. Catalog & Product Management**

* Full CRUD support for products, categories, SKU/barcodes, and pricing tiers.  
* Custom thermal label layout and printable QR code generation.

## **C. Employee & Role Management**

* Account creation, PIN assignment, activation status, and sales breakdown per employee.

## **D. Inventory & Stock Control**

* Stock level tracking, manual entry logs, low-stock threshold alerts, and central stock adjustments.

## **E. Transaction & Audit Management**

* Filterable master order list (by date, cashier, payment method, or invoice ID) with receipt re-printing capabilities.

## **F. Sync Gateway Server**

* Multi-device connection dashboard, device pairing management, transmission logs, and manual reconciliation tools.

# **5\. Database Architecture**

The system utilizes SQLite across all platforms, abstracted using **Drift (Dart)**.

# **5.1 Data Table Reference**

| Table Name | Description / Responsibility |
| :---- | :---- |
| `products` | Master product catalog and selling parameters. |
| `categories` | Product classification taxonomy. |
| `employees` | Employee accounts, PIN hashes, and access rights. |
| `customers` | Optional customer contact information. |
| `invoices` | Invoice transaction headers. |
| `invoice_items` | Snapshot of line items bound to specific invoices. |
| `inventory` | Real-time stock levels on the Windows central node. |
| `inventory_movements` | Immutable audit log of stock adjustments. |
| `devices` | Registered mobile terminals. |
| `sync_queue` | Local pending synchronization state machine. |
| `app_settings` | Key-value store configuration parameters. |

# **5.2 Schema Definitions**

## **Products Table**

```
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

## **Invoices Table**

```
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

## **Invoice Items Table**

```
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

*Note: `invoice_items` must store point-in-time snapshots of `product_name`, `unit_price`, and `tax_amount` to ensure price edits to the product catalog never affect historic sales records.*

## **Sync Queue Table**

```
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

# **6\. Synchronization Architecture**

# **6.1 Sync Protocol Details**

* **Transport:** Local HTTP REST over Wi-Fi network.  
* **Server Architecture:** Lightweight HTTP server running embedded in the Windows app using `Dart Shelf`.  
* **Zero Internet Reliance:** Communication occurs strictly within local IP subnets.

# **6.2 Peer Device Pairing Workflow**

```
[Windows App Starts Server] ---> [Displays Pairing QR Code (IP + Port + Token)]
                                                    |
                                                    v
[Desktop Registers Terminal] <--- [Mobile Scans Pairing QR Code]
```

# **6.3 Data Synchronization Matrix**

| Direction | Dataset Payload | Trigger Mechanism |
| :---- | :---- | :---- |
| **Windows → Mobile** | Product Catalog Updates | Periodic poll / Re-connection event |
| **Windows → Mobile** | Category Taxonomies | Periodic poll / Re-connection event |
| **Windows → Mobile** | Employee Accounts & Permissions | On application launch / Sync |
| **Mobile → Windows** | Completed Order Invoices | Immediate post-sale / Queue drain |
| **Mobile → Windows** | Order Line Items | Immediate post-sale / Queue drain |
| **Mobile ↔ Windows** | Device Registration Handshake | Initial pairing scan |
| **Windows → Mobile** | Order Transaction ACK | Response to sync payload upload |

# **6.4 Duplicate Prevention Mechanism**

* **Primary Key Enforcement:** All transactions generate a v4 UUID at creation on the mobile terminal.  
* **Idempotent Storage Strategy:** When receiving an invoice payload, the Windows server checks if the incoming UUID exists in `invoices.id`.  
* **Safe ACK:** If the UUID exists, the desktop ignores duplicate insertion and returns an `HTTP 200 ACK` to clear the mobile terminal's queue safely.

# **7\. Technology Stack Matrix**

| Module / Component | Selected Framework / Library | Description |
| :---- | :---- | :---- |
| **UI Framework** | Flutter (Dart 3.x) | Cross-platform framework targeting Android & Windows. |
| **Local Database** | SQLite via Drift | Reactive persistence engine with compile-time SQL checks. |
| **State Management** | Flutter Riverpod | Predictable, reactive state isolation layer. |
| **Barcode Scanner** | `mobile_scanner` | Native camera pipeline for real-time barcode decoding. |
| **Desktop HTTP Server** | `shelf` / `shelf_router` | Embedded asynchronous Web server for Windows node. |
| **HTTP Client** | `dio` | Powerful networking client with retry interceptors. |
| **Device Discovery** | `nsd` (mDNS) | Local network zero-configuration service discovery. |
| **PDF Generation** | `pdf` / `printing` | Vector-graphics based layout engine for thermal/A4 receipts. |
| **Sharing Hooks** | `share_plus` | Cross-platform access to native OS sharing utilities. |
| **Secure Key Store** | `flutter_secure_storage` | Encrypted storage for pairing tokens and PIN credentials. |

# **8\. Security & Reliability Model**

## **Security Controls**

* **Authentication:** Employees log in with hashed PIN codes stored locally via SHA-256 with device-specific salt.  
* **API Protection:** HTTP server endpoints require bearer tokens issued during the initial QR pairing handshake.  
* **Network Isolation:** HTTP API strictly binds to local intranet interface addresses (e.g., `192.168.x.x`), ignoring external interface traffic.

## **System Reliability**

* **Atomic Transactions:** Invoice generation and item persistence are wrapped in single-transaction database operations.  
* **Offline Resilience:** Mobile terminals function perpetually without server contact; sync queues automatically resume operations when the local server becomes reachable.

# **9\. Inventory Consistency Rules**

In multi-terminal offline environments, product stock levels can drift if managed dynamically on mobile terminals.

```
SCENARIO:
- Initial Desktop Stock: 10 units of "Item A"
- Mobile Phone 1 (Offline): Sells 2 units
- Mobile Phone 2 (Offline): Sells 3 units

RECONCILIATION LOGIC:
1. Mobile devices DO NOT send absolute remaining stock numbers.
2. Mobile devices transmit Delta Inventory Movements (e.g., -2 units, -3 units).
3. Upon synchronization, the Desktop applies delta entries sequentially to the master stock ledger.
4. Final Consolidated Stock = 10 - 2 - 3 = 5 units.
```

*Rule: Mobile terminals display cached stock estimates. The Windows application maintains authoritative inventory records.*

# **10\. Backup & Data Recovery Strategy**

Because the environment operates entirely without cloud infrastructure, the Windows central node manages backup maintenance.

1. **Scheduled Daily Backups:** Automated SQLite snapshots written to designated local storage volumes.  
2. **External USB Backups:** Manual one-click database export routines targeting removable storage media.  
3. **Data Export Options:** Analytical reporting and history exportable to standardized formats (`.csv`, `.xlsx`, `.pdf`).  
4. **Mobile Queue Safeguards:** Mobile terminals preserve non-acknowledged transaction queue records until explicit confirmation is received from the central node.

# **11\. Development Roadmap**

| Phase | Milestone Scope | Core Deliverables |
| :---- | :---- | :---- |
| **Phase 1** | Base Architecture | Shared monorepo setup, Drift database schemas, base models, authentication PIN flows. |
| **Phase 2** | Mobile POS Module | Barcode camera integrations, cart state management, checkout calculations, offline PDF rendering. |
| **Phase 3** | Desktop Admin | Dashboard UX, product CRUD operations, inventory ledger engine, employee role panels. |
| **Phase 4** | Synchronization Engine | Embedded Shelf HTTP server implementation, QR pairing flows, queue sync engine, reconciliation logic. |
| **Phase 5** | Production Readiness | Thermal printer drivers, end-to-end security audits, failure recovery stress testing, store deployment setup. |

# **12\. MVP Acceptance Criteria**

- [x] **100% Offline Checkout:** Cashiers can log in, scan items, process cart calculations, and generate receipt PDFs without any network interface active.  
- [x] **Local Multi-Device Sync:** Multiple Android devices connected to the local store Wi-Fi network synchronize completed invoices to the central Windows node.  
- [x] **Zero Cloud Dependency:** The entire billing lifecycle functions with zero calls to public cloud endpoints.  
- [x] **Idempotency Safeguard:** Network interruptions and retries do not create duplicate sales entries on the Windows server.  
- [x] **Continuous Cashier Availability:** Turning off or rebooting the central Windows desktop does not lock out mobile terminal billing operations.  
- [x] **Product Catalog Distribution:** Updates to prices or catalog items made on the Windows admin app reflect automatically on mobile terminals upon reconnecting.  
- [x] **Backup Recovery:** Store administrators can back up and restore central transactional databases from local file storage or USB drives.

