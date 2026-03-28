import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class NotificationsScreen extends StatefulWidget {
  final int clientId;
  final int employeeId;
  final String? employeeNumber;

  const NotificationsScreen({
    super.key,
    required this.clientId,
    required this.employeeId,
    this.employeeNumber,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _loadError;
  bool _selectionMode = false;
  final Set<int> _selectedNotificationIds = {};
  late int _effectiveEmployeeId;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _effectiveEmployeeId = widget.employeeId;
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      var notifications = await ApiService.getNotifications(
        widget.clientId,
        _effectiveEmployeeId,
      );
      if (notifications.isEmpty && widget.employeeNumber != null) {
        final parsed = int.tryParse(widget.employeeNumber!.trim());
        if (parsed != null && parsed > 0 && parsed != _effectiveEmployeeId) {
          final fallback = await ApiService.getNotifications(widget.clientId, parsed);
          if (fallback.isNotEmpty) {
            notifications = fallback;
            _effectiveEmployeeId = parsed;
          }
        }
      }
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loadError = null;
          _selectionMode = false;
          _selectedNotificationIds.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notification.id);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: notification.id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          requestId: notification.requestId,
          requestType: notification.requestType,
          relatedLink: notification.relatedLink,
          isRead: true,
          createdDate: notification.createdDate,
          readAt: notification.readAt,
          createdBy: notification.createdBy,
          metadata: notification.metadata,
        );
      }
    });
    await ApiService.markNotificationRead(widget.clientId, notification.id);
  }

  Future<void> _markAllRead() async {
    final ok = await ApiService.markAllNotificationsRead(widget.clientId, _effectiveEmployeeId);
    if (!ok) return;
    await _loadNotifications();
  }

  Future<void> _markSelectedRead() async {
    final ids = _selectedNotificationIds.toList(growable: false);
    if (ids.isEmpty) return;

    final ok = await ApiService.markNotificationsReadBulk(widget.clientId, _effectiveEmployeeId, ids);
    if (!ok) {
      for (final id in ids) {
        await ApiService.markNotificationRead(widget.clientId, id);
      }
    }
    await _loadNotifications();
  }

  void _toggleSelection(int notificationId) {
    setState(() {
      _selectionMode = true;
      if (_selectedNotificationIds.contains(notificationId)) {
        _selectedNotificationIds.remove(notificationId);
        if (_selectedNotificationIds.isEmpty) _selectionMode = false;
      } else {
        _selectedNotificationIds.add(notificationId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedNotificationIds.clear();
    });
  }

  void _selectAllVisible(List<NotificationModel> visible) {
    setState(() {
      _selectionMode = true;
      _selectedNotificationIds
        ..clear()
        ..addAll(visible.map((e) => e.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    final all = _notifications;
    final unread = all.where((n) => !n.isRead).toList(growable: false);
    final read = all.where((n) => n.isRead).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode 
              ? '${Translations.getText('selection', lang)} (${_selectedNotificationIds.length})' 
              : Translations.getText('notifications', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _selectionMode
            ? IconButton(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (_selectionMode)
            IconButton(
              onPressed: _markSelectedRead,
              icon: const Icon(Icons.mark_email_read_outlined),
              tooltip: Translations.getText('mark_as_read', lang),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'mark_all') {
                  await _markAllRead();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all',
                  child: Text(Translations.getText('mark_all_read', lang)),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: '${Translations.getText('all_notifications', lang)} (${all.length})'),
            Tab(text: '${Translations.getText('unread_notifications', lang)} (${unread.length})'),
            Tab(text: '${Translations.getText('read_notifications', lang)} (${read.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_loadError != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off,
                            size: 56, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          Translations.getText('error_loading_notifications', lang),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Translations.getText('check_connection_try_again', lang),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadNotifications,
                          child: Text(Translations.getText('retry', lang)),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(all, scheme),
                    _buildList(unread, scheme),
                    _buildList(read, scheme),
                  ],
                ),
    );
  }

  Widget _buildList(List<NotificationModel> items, ColorScheme scheme) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              Translations.getText('no_notifications', lang),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final notification = items[index];
          final isSelected = _selectedNotificationIds.contains(notification.id);
          final isUnread = !notification.isRead;
          final bg = isUnread ? scheme.primaryContainer.withOpacity(0.35) : scheme.surface;
          final titleText = notification.title.trim().isEmpty ? Translations.getText('notification', lang) : notification.title.trim();
          final messageText = notification.message.trim();
          final typeText = (notification.requestType ?? notification.type)?.toString().trim();
          final hasType = typeText != null && typeText.isNotEmpty;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _selectionMode && isSelected ? scheme.secondaryContainer : bg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.8)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: () => _toggleSelection(notification.id),
              onTap: (!_selectionMode && !isUnread)
                  ? null
                  : () async {
                if (_selectionMode) {
                  _toggleSelection(notification.id);
                  return;
                }
                await _markAsRead(notification);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectionMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(notification.id),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isUnread ? scheme.primary : scheme.outlineVariant,
                          foregroundColor: isUnread ? scheme.onPrimary : scheme.onSurface,
                          child: Icon(_getIconForType(notification.requestType ?? notification.type), size: 18),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  titleText,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!_selectionMode && isUnread)
                                Padding(
                                  padding: const EdgeInsets.only(right: 2, top: 2),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (hasType) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                typeText!,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                          if (messageText.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                messageText,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  notification.createdDate,
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (notification.createdBy != null && notification.createdBy!.trim().isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    notification.createdBy!.trim(),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'leave':
      case 'إجازة':
        return Icons.beach_access;
      case 'loan':
      case 'سلفة':
        return Icons.attach_money;
      default:
        return Icons.notifications;
    }
  }
}
