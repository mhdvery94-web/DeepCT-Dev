import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/pagination.dart';
import '../../models/user_model.dart';
import '../../services/admin_user_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/status_badge.dart';

/// Admin screen for listing and managing platform users.
///
/// Covers all 7 backend endpoints: list (search/filter/paginate), create,
/// update, delete, toggle status and reset password.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminUserService _service = AdminUserService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _users = [];
  Pagination _pagination = const Pagination.empty();

  bool _isLoading = true;
  String? _error;

  int _page = 1;
  String? _roleFilter;
  String? _statusFilter;

  /// Debounces the search field so we don't fire a request per keystroke.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.list(
        page: _page,
        search: _searchController.text.trim(),
        role: _roleFilter,
        status: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        _users = result.items;
        _pagination = result.pagination;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _page = 1;
      _load();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _openUserDialog({UserModel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog(service: _service, existing: existing),
    );

    if (saved == true) {
      if (existing == null) _page = 1;
      _load();
    }
  }

  Future<void> _toggleStatus(UserModel user) async {
    try {
      await _service.toggleStatus(user.id);
      _showMessage(
        user.isActive
            ? '${user.username} has been deactivated'
            : '${user.username} has been activated',
      );
      _load();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    }
  }

  Future<void> _resetPassword(UserModel user) async {
    final confirmed = await _confirm(
      title: 'Reset password',
      message:
          'Reset the password for "${user.username}" to the platform default?',
      confirmLabel: 'RESET',
    );
    if (confirmed != true) return;

    try {
      final password = await _service.resetPassword(user.id);
      if (!mounted) return;

      // Surface the new credential so the admin can pass it on.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('Password reset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New password for ${user.username}:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.background,
                child: SelectableText(
                  password,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('DONE'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    }
  }

  Future<void> _delete(UserModel user) async {
    final confirmed = await _confirm(
      title: 'Delete user',
      message: 'Permanently delete "${user.username}"? This cannot be undone.',
      confirmLabel: 'DELETE',
      destructive: true,
    );
    if (confirmed != true) return;

    try {
      await _service.delete(user.id);
      _showMessage('${user.username} deleted');

      // Step back a page if we just removed the only row on it.
      if (_users.length == 1 && _page > 1) _page--;
      _load();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: destructive
                ? ElevatedButton.styleFrom(backgroundColor: AppTheme.error)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Expanded(child: _buildContent()),
                  PaginationBar(
                    pagination: _pagination,
                    onPageChanged: (p) {
                      _page = p;
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search name, username, email',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _page = 1;
                        _load();
                      },
                    ),
            ),
          ),
        ),
        _FilterDropdown(
          hint: 'All roles',
          value: _roleFilter,
          items: const {'admin': 'Admin', 'user': 'User'},
          onChanged: (v) {
            setState(() {
              _roleFilter = v;
              _page = 1;
            });
            _load();
          },
        ),
        _FilterDropdown(
          hint: 'All statuses',
          value: _statusFilter,
          items: const {'active': 'Active', 'inactive': 'Inactive'},
          onChanged: (v) {
            setState(() {
              _statusFilter = v;
              _page = 1;
            });
            _load();
          },
        ),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('REFRESH'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openUserDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('ADD USER'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const LoadingView(message: 'Loading users...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_users.isEmpty) {
      return const EmptyView(
        message: 'No users match the current filters.',
        icon: Icons.people_outline,
      );
    }

    // The current admin cannot delete or deactivate their own account.
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.background),
                columns: const [
                  DataColumn(label: Text('USER')),
                  DataColumn(label: Text('EMAIL')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('LAST LOGIN')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: _users.map((user) {
                  final isSelf = user.id == currentUserId;

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    '(you)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(user.email)),
                      DataCell(StatusBadge.role(user.role)),
                      DataCell(StatusBadge.active(user.isActive)),
                      DataCell(
                        Text(
                          user.lastLoginAt != null
                              ? dateFormat.format(user.lastLoginAt!.toLocal())
                              : 'Never',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _openUserDialog(existing: user),
                            ),
                            IconButton(
                              tooltip: isSelf
                                  ? 'You cannot change your own status'
                                  : (user.isActive ? 'Deactivate' : 'Activate'),
                              icon: Icon(
                                user.isActive
                                    ? Icons.toggle_on
                                    : Icons.toggle_off_outlined,
                                size: 22,
                                color: user.isActive
                                    ? AppTheme.success
                                    : AppTheme.textMuted,
                              ),
                              onPressed: isSelf
                                  ? null
                                  : () => _toggleStatus(user),
                            ),
                            IconButton(
                              tooltip: 'Reset password',
                              icon: const Icon(Icons.key_outlined, size: 18),
                              onPressed: () => _resetPassword(user),
                            ),
                            IconButton(
                              tooltip: isSelf
                                  ? 'You cannot delete your own account'
                                  : 'Delete',
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: isSelf
                                    ? AppTheme.borderDark
                                    : AppTheme.error,
                              ),
                              onPressed: isSelf ? null : () => _delete(user),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact dropdown used for the role/status filters.
class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.textMuted),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          borderRadius: BorderRadius.zero,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(hint)),
            ...items.entries.map(
              (e) =>
                  DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Create / edit dialog. Password is only offered on create, matching the
/// backend which does not accept password changes through update().
class _UserFormDialog extends StatefulWidget {
  final AdminUserService service;
  final UserModel? existing;

  const _UserFormDialog({required this.service, this.existing});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _password;

  String _role = 'user';
  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.name ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _password = TextEditingController();
    _role = u?.role ?? 'user';
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.service.update(
          id: widget.existing!.id,
          name: _name.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          role: _role,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final result = await widget.service.create(
          name: _name.text.trim(),
          username: _username.text.trim(),
          email: _email.text.trim(),
          role: _role,
          password: _password.text.trim().isEmpty
              ? null
              : _password.text.trim(),
        );

        if (!mounted) return;
        Navigator.pop(context, true);

        // When the backend assigned the default password, show it once.
        final defaultPassword = result.defaultPassword;
        if (defaultPassword != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User created. Default password: $defaultPassword'),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text(_isEdit ? 'Edit user' : 'Add user'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'FULL NAME'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Full name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'USERNAME'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'EMAIL'),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Email is required';
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'ROLE'),
                  borderRadius: BorderRadius.zero,
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(
                      labelText: 'PASSWORD (OPTIONAL)',
                      helperText: 'Leave blank to use BrinResearch2026',
                    ),
                    obscureText: true,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isNotEmpty && value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEdit ? 'SAVE' : 'CREATE'),
        ),
      ],
    );
  }
}
