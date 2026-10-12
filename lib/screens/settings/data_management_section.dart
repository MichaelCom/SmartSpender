import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/repositories.dart';
import '../../services/backup_service.dart';

/// The "Data" section of the Settings screen.
///
/// Provides three actions backed by [BackupService]:
/// - Export backup (JSON): full data backup, shared via the OS share sheet.
/// - Export transactions (CSV): transactions-only, shared via the OS share
///   sheet.
/// - Restore from backup (JSON): picks a `.json` file, confirms a destructive
///   REPLACE, restores, then refreshes the data providers so the UI updates.
///
/// All actions obtain the service via `BackupService(context.read<AppRepositories>())`.
/// Post-await `context` use is guarded with `mounted` checks.
class DataManagementSection extends StatefulWidget {
  const DataManagementSection({super.key});

  @override
  State<DataManagementSection> createState() => _DataManagementSectionState();
}

class _DataManagementSectionState extends State<DataManagementSection> {
  bool _busy = false;

  BackupService _service() => BackupService(context.read<AppRepositories>());

  @override
  Widget build(BuildContext context) {
    final busyTrailing = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Export backup (JSON)'),
          subtitle: const Text('Full backup you can restore later'),
          trailing: busyTrailing ?? const Icon(Icons.ios_share),
          enabled: !_busy,
          onTap: _busy ? null : _exportJson,
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export transactions (CSV)'),
          subtitle: const Text('Transactions only, for spreadsheets'),
          trailing: busyTrailing ?? const Icon(Icons.ios_share),
          enabled: !_busy,
          onTap: _busy ? null : _exportCsv,
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore),
          title: const Text('Restore from backup (JSON)'),
          subtitle: const Text('Replaces all current data'),
          trailing: busyTrailing ?? const Icon(Icons.chevron_right),
          enabled: !_busy,
          onTap: _busy ? null : _restoreJson,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          child: Text(
            'Backups store raw amounts as-is; no currency conversion is '
            'applied.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Export: JSON backup
  // ---------------------------------------------------------------------------

  Future<void> _exportJson() async {
    final service = _service();
    setState(() => _busy = true);
    try {
      final jsonString = await service.exportToJsonString();
      final fileName = 'smartspender-backup-${_timestamp()}.json';
      await _shareString(
        contents: jsonString,
        fileName: fileName,
        mimeType: 'application/json',
        subject: 'SmartSpender backup',
      );
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Export: CSV transactions
  // ---------------------------------------------------------------------------

  Future<void> _exportCsv() async {
    final service = _service();
    setState(() => _busy = true);
    try {
      final csv = await service.exportTransactionsToCsvString();
      final fileName = 'smartspender-transactions-${_timestamp()}.csv';
      await _shareString(
        contents: csv,
        fileName: fileName,
        mimeType: 'text/csv',
        subject: 'SmartSpender transactions',
      );
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes [contents] to a temp file and hands it to the OS share sheet.
  Future<void> _shareString({
    required String contents,
    required String fileName,
    required String mimeType,
    required String subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: fileName)],
      subject: subject,
    );
  }

  // ---------------------------------------------------------------------------
  // Restore: JSON backup (Replace)
  // ---------------------------------------------------------------------------

  Future<void> _restoreJson() async {
    // Pick a .json file.
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: false,
      );
    } catch (e) {
      _showSnack('Could not open file picker: $e');
      return;
    }

    if (picked == null || picked.files.isEmpty) {
      return; // user cancelled
    }

    final path = picked.files.single.path;
    if (path == null) {
      _showSnack('Could not read the selected file.');
      return;
    }

    // Read the file contents.
    final String jsonString;
    try {
      jsonString = await File(path).readAsString();
    } catch (e) {
      _showSnack('Could not read the selected file: $e');
      return;
    }

    // Confirm the destructive replace.
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This will REPLACE all current data with the contents of the '
          'selected backup. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final service = _service();
    setState(() => _busy = true);
    try {
      final result = await service.restoreFromJson(jsonString);
      if (result.success) {
        // Refresh the three data providers so the UI reflects the new data.
        await _refreshProviders();
        _showSnack(result.message);
      } else {
        _showSnack(result.message);
      }
    } catch (e) {
      _showSnack('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshProviders() async {
    if (!mounted) return;
    final categories = context.read<CategoryProvider>();
    final transactions = context.read<TransactionProvider>();
    final budgets = context.read<BudgetProvider>();
    await Future.wait([
      categories.loadCategories(),
      transactions.loadTransactions(),
      budgets.loadBudgets(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// `YYYYMMDD-HHmmss` timestamp for filenames.
  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${now.year.toString().padLeft(4, '0')}'
        '${two(now.month)}${two(now.day)}';
    final time = '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return '$date-$time';
  }
}
