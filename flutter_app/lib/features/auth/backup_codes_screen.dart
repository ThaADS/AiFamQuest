import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/client.dart';

/// Screen for viewing and managing 2FA backup codes
///
/// Displays current backup codes with options to:
/// - Copy all codes to clipboard
/// - Download codes as TXT file
/// - Regenerate new codes (invalidates old ones)
class BackupCodesScreen extends StatefulWidget {
  final List<String>? existingCodes;

  const BackupCodesScreen({
    super.key,
    this.existingCodes,
  });

  @override
  State<BackupCodesScreen> createState() => _BackupCodesScreenState();
}

class _BackupCodesScreenState extends State<BackupCodesScreen> {
  List<String>? _backupCodes;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backupCodes = widget.existingCodes;
    if (_backupCodes == null) {
      _loadBackupCodes();
    }
  }

  Future<void> _loadBackupCodes() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.getBackupCodes();
      setState(() {
        _backupCodes = List<String>.from(response['backup_codes']);
      });
    } catch (e) {
      setState(() => _error = 'Failed to load backup codes: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _regenerateBackupCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Backup Codes?'),
        content: const Text(
          'This will invalidate all your current backup codes. '
          'Make sure to save the new codes in a secure location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.regenerateBackupCodes();
      setState(() {
        _backupCodes = List<String>.from(response['backup_codes']);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New backup codes generated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _error = 'Failed to regenerate codes: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _copyAllCodes() {
    if (_backupCodes == null) return;

    final codesText = _backupCodes!.join('\n');
    Clipboard.setData(ClipboardData(text: codesText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All backup codes copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadCodes() {
    // TODO: Implement file download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Codes'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _busy ? null : _regenerateBackupCodes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate Codes',
          ),
        ],
      ),
      body: _busy && _backupCodes == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade900),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keep these codes safe',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Each code can only be used once. Store them in a password manager or write them down and keep them somewhere secure.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Backup codes grid
                  if (_backupCodes != null)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _backupCodes!.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: SelectableText(
                              _backupCodes![index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _copyAllCodes,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _downloadCodes,
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                        ),
                      ),
                    ],
                  ),

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'About Backup Codes',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            'When to use',
                            'Use a backup code if you lose access to your authenticator app',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            'Single-use',
                            'Each code can only be used once',
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            'Regenerate anytime',
                            'You can generate new codes whenever you need them',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
