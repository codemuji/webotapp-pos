import 'package:database/database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

/// Employee and cashier security management screen for setting 4-digit PINs and roles.
class EmployeeManagementScreen extends StatefulWidget {
  final AppDatabase database;

  const EmployeeManagementScreen({
    super.key,
    required this.database,
  });

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final list = await widget.database.getAllEmployees();
    if (mounted) {
      setState(() {
        _employees = list;
        _isLoading = false;
      });
    }
  }

  void _showEmployeeDialog([Employee? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final pinCtrl = TextEditingController();
    String selectedRole = existing?.role ?? 'cashier';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'New Employee Registration' : 'Edit Employee',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('input_employee_name'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'admin', child: Text('Store Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('input_employee_pin'),
                  controller: pinCtrl,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: existing == null ? '4-Digit Login PIN' : 'New PIN (leave blank to keep current)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();

                if (name.isNotEmpty && (existing != null || pin.length == 4)) {
                  final empId = existing?.id ?? 'emp-${DateTime.now().millisecondsSinceEpoch}';
                  final pinHash = pin.isNotEmpty ? pin : (existing?.pinHash ?? '0000');

                  await widget.database.upsertEmployee(
                    EmployeesCompanion.insert(
                      id: empId,
                      name: name,
                      pinHash: pinHash,
                      role: Value(selectedRole),
                      isActive: Value(existing?.isActive ?? true),
                      createdAt: existing?.createdAt ?? DateTime.now(),
                    ),
                  );

                  if (mounted) Navigator.of(ctx).pop();
                  await _loadEmployees();
                }
              },
              child: const Text('Save Employee'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee & Security Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage staff credentials, 4-digit PINs, and role-based permissions',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showEmployeeDialog(),
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        label: const Text('Add Employee'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Employees List Container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: _employees.length + 1,
                          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildTableHeader();
                            }
                            final emp = _employees[index - 1];
                            return _buildEmployeeRow(emp);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('PIN Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Employee emp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  emp.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: emp.role == 'admin' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: emp.role == 'admin' ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  emp.role,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: emp.role == 'admin' ? const Color(0xFF2563EB) : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: emp.isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: emp.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  emp.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: emp.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '•••• (Set)',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), letterSpacing: 2),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Edit Employee',
                  onPressed: () => _showEmployeeDialog(emp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
