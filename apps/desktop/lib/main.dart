import 'dart:async';
import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'src/auth/admin_lock_screen.dart';
import 'src/backup/backup_restore_screen.dart';
import 'src/catalog/expiry_tracker_screen.dart';
import 'src/catalog/low_stock_screen.dart';
import 'src/catalog/product_catalog_screen.dart';
import 'src/dashboard/admin_dashboard_screen.dart';
import 'src/sales/sales_transactions_screen.dart';
import 'src/sync/sync_server_screen.dart';
import 'src/theme/webotapp_logo.dart';
import 'src/theme/webotapp_theme.dart';

void _logCrash(Object error, StackTrace stack) {
  try {
    getApplicationSupportDirectory().then((dir) {
      final file = File(p.join(dir.path, 'desktop_crash.log'));
      file.writeAsStringSync('CRASH [${DateTime.now()}]: $error\n$stack\n', mode: FileMode.append);
    });
  } catch (_) {}
}

final adminDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});

final desktopSyncServerProvider = Provider<SyncServer>((ref) {
  final db = ref.watch(adminDatabaseProvider);
  final server = SyncServer(database: db, storeName: 'WebotApp Store');
  // Auto-start server in background across all views (skipped in widget tests to avoid port conflicts)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    server.start(host: InternetAddress.anyIPv4, port: 8085).catchError((e, st) {
      _logCrash(e, st);
      debugPrint('Auto-start sync server error on port 8085: $e');
    });
  }
  ref.onDispose(() {
    server.stop();
  });
  return server;
});

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      _logCrash(details.exception, details.stack ?? StackTrace.current);
    };

    AppDatabase? db;
    try {
      final appDir = await getApplicationSupportDirectory();
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      final dbFile = File(p.join(appDir.path, 'grocery_pos_admin.db'));
      db = AppDatabase.fromFile(dbFile);

      // Auto-populate comprehensive realistic retail mock dataset (750+ products & 450+ invoices)
      final prods = await db.getAllProducts();
      if (prods.length < 50) {
        await seedDemoStoreData(db);
      }
    } catch (e, st) {
      _logCrash(e, st);
      debugPrint('Could not initialize persistent admin database: $e');
    }

    runApp(
      ProviderScope(
        overrides: [
          if (db != null) adminDatabaseProvider.overrideWithValue(db),
        ],
        child: const GroceryPosDesktopAdminApp(),
      ),
    );
  }, (error, stack) {
    _logCrash(error, stack);
  });
}

class GroceryPosDesktopAdminApp extends ConsumerStatefulWidget {
  final bool initialLocked;

  const GroceryPosDesktopAdminApp({
    super.key,
    this.initialLocked = true,
  });

  @override
  ConsumerState<GroceryPosDesktopAdminApp> createState() => _GroceryPosDesktopAdminAppState();
}

class _GroceryPosDesktopAdminAppState extends ConsumerState<GroceryPosDesktopAdminApp> {
  late bool _isLocked;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initialLocked;
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  void _lock() {
    setState(() => _isLocked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Keep sync server alive globally in background
    ref.watch(desktopSyncServerProvider);

    return MaterialApp(
      title: 'WebotApp Departmental POS — Store Admin Console',
      debugShowCheckedModeBanner: false,
      theme: WebotAppTheme.lightTheme,
      scrollBehavior: const DesktopSmoothScrollBehavior(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _isLocked
            ? AdminLockScreen(
                key: const ValueKey('admin_lock_screen'),
                onUnlocked: _unlock,
              )
            : AdminShellView(
                key: const ValueKey('admin_shell_view'),
                onLock: _lock,
              ),
      ),
    );
  }
}

class AdminShellView extends ConsumerStatefulWidget {
  final VoidCallback onLock;

  const AdminShellView({
    super.key,
    required this.onLock,
  });

  @override
  ConsumerState<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends ConsumerState<AdminShellView> {
  int _selectedIndex = 0;
  int _lowStockAlertCount = 0;
  int _expiringAlertCount = 0;
  List<Widget>? _cachedScreens;
  AppDatabase? _lastDb;
  SyncServer? _lastServer;

  @override
  void initState() {
    super.initState();
    _loadAlertCounts();
  }

  Future<void> _loadAlertCounts() async {
    final db = ref.read(adminDatabaseProvider);
    try {
      final low = await db.getLowStockProducts();
      final expiring = await db.getExpiringProducts(days: 30);
      if (mounted) {
        setState(() {
          _lowStockAlertCount = low.length;
          _expiringAlertCount = expiring.length;
        });
      }
    } catch (_) {}
  }

  List<Widget> _getScreens(AppDatabase db, SyncServer server) {
    if (_cachedScreens == null || _lastDb != db || _lastServer != server) {
      _lastDb = db;
      _lastServer = server;
      _cachedScreens = [
        AdminDashboardScreen(
          database: db,
          onNavigateToSales: () => setState(() => _selectedIndex = 1),
        ),
        SalesTransactionsScreen(database: db),
        ProductCatalogScreen(database: db),
        LowStockScreen(database: db),
        ExpiryTrackerScreen(database: db),
        SyncServerScreen(database: db, storeName: 'WebotApp Store', server: server),
        BackupRestoreScreen(database: db, isSimulationMode: true),
      ];
    }
    return _cachedScreens!;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(adminDatabaseProvider);
    final server = ref.watch(desktopSyncServerProvider);
    final screens = _getScreens(db, server);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Executive Dark Desktop Sidebar (Matching Production UI)
          Container(
            width: 236,
            color: WebotAppTheme.darkSlate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Center(
                          child: WebotAppLogoMark(size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                                children: [
                                  TextSpan(text: '⚡ WEBOT', style: TextStyle(color: Colors.white)),
                                  TextSpan(text: 'APP', style: TextStyle(color: Color(0xFF00C853))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'DEPARTMENTAL POS',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.8,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1, thickness: 1),
                const SizedBox(height: 12),

                // Navigation Items List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      _buildSidebarItem(
                        index: 0,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                      ),
                      _buildSidebarItem(
                        index: 1,
                        icon: Icons.receipt_long_rounded,
                        label: 'Sales',
                      ),
                      _buildSidebarItem(
                        index: 2,
                        icon: Icons.inventory_2_rounded,
                        label: 'Catalog',
                      ),
                      _buildSidebarItem(
                        index: 3,
                        icon: Icons.warning_amber_rounded,
                        label: 'Low Stock',
                        badgeCount: _lowStockAlertCount,
                        badgeColor: const Color(0xFFEF4444),
                      ),
                      _buildSidebarItem(
                        index: 4,
                        icon: Icons.event_busy_rounded,
                        label: 'Expiry',
                        badgeCount: _expiringAlertCount,
                        badgeColor: const Color(0xFFF97316),
                      ),
                      _buildSidebarItem(
                        index: 5,
                        icon: Icons.sync_rounded,
                        label: 'Terminals',
                      ),
                      _buildSidebarItem(
                        index: 6,
                        icon: Icons.backup_rounded,
                        label: 'Backups',
                      ),
                    ],
                  ),
                ),

                // Lock Console / Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onLock,
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: const Color(0xFFEF4444).withOpacity(0.12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: Color(0xFFF87171),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Lock Console',
                                style: TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Bottom Sync Server Daemon Status Card
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF10B981),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sync Daemon Online',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Port 8085 • Connected',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF1E293B)),
          Expanded(
            child: FadeIndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
    Color badgeColor = const Color(0xFFEF4444),
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_selectedIndex != index) {
              setState(() => _selectedIndex = index);
            }
          },
          borderRadius: BorderRadius.circular(8),
          hoverColor: const Color(0xFF1E293B).withOpacity(0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: const Color(0xFF334155), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                if (isSelected)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// High-performance cross-fade transition wrapper over [IndexedStack].
/// Retains active widget state while delivering smooth 160ms ease-out transitions between tabs.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 160),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}

