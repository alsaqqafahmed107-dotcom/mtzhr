import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_task.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import '../theme/app_semantic_colors.dart';
import 'user_task_details_screen.dart';

class UserTasksScreen extends StatefulWidget {
  final int clientId;
  final int employeeId;

  const UserTasksScreen({
    super.key,
    required this.clientId,
    required this.employeeId,
  });

  @override
  State<UserTasksScreen> createState() => _UserTasksScreenState();
}

class _UserTasksScreenState extends State<UserTasksScreen> {
  bool _isLoading = false;
  String _statusFilter = 'All';
  List<UserTask> _tasks = const [];
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getUserTasks(
        widget.clientId,
        employeeId: widget.employeeId,
        status: _statusFilter == 'All' ? null : _statusFilter,
        page: 1,
        pageSize: 100,
      );

      final ok = response['Success'] == true;
      final msg = response['Message']?.toString();
      final List data = (response['Data'] as List?) ?? const [];
      final tasks = ok
          ? data
              .whereType<Map<String, dynamic>>()
              .map(UserTask.fromJson)
              .toList()
          : <UserTask>[];

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _lastError = ok ? null : (msg?.isNotEmpty == true ? msg : 'تعذر تحميل المهام');
      });

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lastError!)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusLabel(String lang, String status) {
    switch (status) {
      case 'Pending':
        return Translations.getText('tasks_status_pending', lang);
      case 'InProgress':
        return Translations.getText('tasks_status_inprogress', lang);
      case 'AwaitingApproval':
        return Translations.getText('tasks_status_awaiting', lang);
      case 'Completed':
        return Translations.getText('tasks_status_completed', lang);
      default:
        return status;
    }
  }

  Color _statusColor(ColorScheme scheme, AppSemanticColors semantic, String status) {
    switch (status) {
      case 'Completed':
        return semantic.success;
      case 'InProgress':
        return scheme.primary;
      case 'AwaitingApproval':
        return scheme.tertiary;
      case 'Pending':
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context).currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('tasks_title', lang)),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatusChipBar(
                    value: _statusFilter,
                    onChanged: (v) async {
                      setState(() => _statusFilter = v);
                      await _load();
                    },
                    lang: lang,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _lastError ?? Translations.getText('tasks_empty', lang),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              if (_lastError != null)
                                OutlinedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(Translations.getText('retry', lang)),
                                ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final t = _tasks[index];
                          final statusColor = _statusColor(scheme, semantic, t.status);
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserTaskDetailsScreen(
                                    clientId: widget.clientId,
                                    employeeId: widget.employeeId,
                                    taskId: t.taskId,
                                  ),
                                ),
                              );
                              if (changed == true) _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: 0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: statusColor.withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Text(
                                                _statusLabel(lang, t.status),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: statusColor,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if ((t.description ?? '').trim().isNotEmpty)
                                          Text(
                                            t.description!.trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(color: scheme.onSurfaceVariant),
                                          ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 18,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                t.dueDateTime ?? '-',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                              ),
                                            ),
                                            if (t.attachmentsCount > 0) ...[
                                              const SizedBox(width: 10),
                                              Icon(
                                                Icons.attach_file_rounded,
                                                size: 18,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                t.attachmentsCount.toString(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatusChipBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String lang;

  const _StatusChipBar({
    required this.value,
    required this.onChanged,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Map<String, String>>[
      {'value': 'All', 'label': Translations.getText('tasks_status_all', lang)},
      {'value': 'Pending', 'label': Translations.getText('tasks_status_pending', lang)},
      {'value': 'InProgress', 'label': Translations.getText('tasks_status_inprogress', lang)},
      {'value': 'AwaitingApproval', 'label': Translations.getText('tasks_status_awaiting', lang)},
      {'value': 'Completed', 'label': Translations.getText('tasks_status_completed', lang)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            ChoiceChip(
              label: Text(item['label']!),
              selected: value == item['value'],
              onSelected: (_) => onChanged(item['value']!),
              selectedColor: scheme.primaryContainer.withValues(alpha: 0.9),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value == item['value'] ? scheme.onPrimaryContainer : null,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
