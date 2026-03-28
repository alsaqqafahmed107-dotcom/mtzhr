import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import '../models/api_models.dart' as api_models;
import '../models/pending_counts.dart';
import '../models/request.dart' as request_models;
import '../models/employee_full_info.dart';

import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'requests_screen.dart';
import 'approvals_screen.dart'
    if (dart.library.html) 'approvals_screen_web_stub.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'payroll_screen.dart';
import 'shift_info_screen.dart';
import 'salary_details_screen.dart';
import '../widgets/responsive_center.dart';
import '../theme/app_semantic_colors.dart';

class HomeScreen extends StatefulWidget {
  final String employeeId;
  final api_models.EmployeeData? employeeData;

  const HomeScreen({
    super.key,
    required this.employeeId,
    this.employeeData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Employee? _currentEmployee;
  Map<String, dynamic> _attendanceStats = {};
  List<String> expiryNotifications = [];
  EmployeeFullInfo? employeeFullInfo;

  // Dashboard Data
  List<request_models.EmployeeRequest> _recentRequests = [];
  int _unreadNotificationsCount = 0;
  PendingCounts? _pendingCounts;
  int _pendingApprovalsCount = 0;
  int _myPendingRequestsCount = 0; // New variable for reliable count
  bool _isLoadingDashboard = false;

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  bool _hasShownExpiryWarning = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Sync setup
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    if (widget.employeeData != null) {
      _currentEmployee = Employee(
        id: widget.employeeData!.employeeID.toString(),
        name: widget.employeeData!.name,
        email: widget.employeeData!.email,
        position:
            '${Translations.getText('employee_number_short', lang)}: ${widget.employeeData!.employeeNumber}',
        department: '',
        phone: '',
        employeeNumber: widget.employeeData!.employeeNumber,
        hireDate: DateTime.now(),
        salary: 0,
      );
    } else {
      _currentEmployee = null;
    }

    _attendanceStats = {
      'hasCheckedIn': false,
      'hasCheckedOut': false,
      'todayAttendance': [],
    };

    if (widget.employeeData == null) return;

    setState(() => _isLoadingDashboard = true);

    try {
      final clientId = widget.employeeData!.clientID;
      final empId = widget.employeeData!.employeeID;
      final email = widget.employeeData!.email;

      final isApprover = widget.employeeData?.rules
                  .toLowerCase()
                  .contains('approver') ==
              true ||
          widget.employeeData?.rules.toLowerCase().contains('مدير') == true ||
          widget.employeeData?.rules.toLowerCase().contains('رئيس') == true;

      // Parallel fetch with isolated error handling
      final results = await Future.wait([
        // 0. Employee Info
        ApiService()
            .getEmployeeFullInfo(clientId, email)
            .then<EmployeeFullInfo?>((v) => v)
            .catchError((e) {
          _log('Error fetching info: $e');
          return null;
        }),

        // 1. Requests (Default to empty map on error)
        ApiService.getRequests(clientId,
                employeeId: empId, page: 1, pageSize: 5)
            .catchError((e) {
          _log('Error fetching requests: $e');
          return {'Success': false, 'Data': []};
        }),

        // 2. Notifications Count (Default to 0)
        ApiService.getUnreadNotificationsCount(clientId, empId).catchError((e) {
          _log('Error fetching notifs count: $e');
          return 0;
        }),

        // 3. Pending Counts (Default to null)
        ApiService.getPendingCounts(clientId, empId).catchError((e) {
          _log('Error fetching pending counts: $e');
          return null;
        }),

        // 4. Pending Approvals (Default to empty)
        (isApprover
                ? ApiService.getPendingRequestsForApproval(clientId,
                    approverId: empId)
                : Future.value({'Success': true, 'Data': []}))
            .catchError((e) {
          _log('Error fetching approvals: $e');
          return {'Success': false, 'Data': []};
        }),

        // 5. My Pending Requests Count (Fallback/Reliable check - Fetch recent history to manually count pending)
        ApiService.getRequests(clientId,
                employeeId: empId, page: 1, pageSize: 50)
            .catchError((e) {
          _log('Error fetching my pending count: $e');
          return {'Success': false, 'Data': []};
        }),
      ]);

      if (!mounted) return;

      setState(() {
        // 1. Employee Full Info & Expiry
        final info = results[0];
        if (info != null && info is EmployeeFullInfo) {
          employeeFullInfo = info;
          if (!_hasShownExpiryWarning) {
            _checkDocumentExpiry(updateState: false);
            _hasShownExpiryWarning = true;
          }
        }

        // 2. Recent Requests
        final requestsResponse = results[1] as Map<String, dynamic>;
        if (requestsResponse['Success'] == true) {
          final List<dynamic> data = requestsResponse['Data'] ?? [];
          _recentRequests =
              data.map((json) => _parseRequestFromAPI(json)).toList();
        }

        // 3. Notifications Count
        _unreadNotificationsCount = results[2] as int;

        // 4. Pending Counts
        _pendingCounts = results[3] as PendingCounts?;

        // 5. Pending Approvals Count
        final approvalsResponse = results[4] as Map<String, dynamic>;
        if (approvalsResponse['Success'] == true) {
          final List<dynamic> data = approvalsResponse['Data'] ?? [];
          _pendingApprovalsCount = data.length;
        } else {
          _pendingApprovalsCount = 0;
        }

        // 6. My Pending Requests Count (Calculated from recent history)
        final myPendingResponse = results[5] as Map<String, dynamic>;
        if (myPendingResponse['Success'] == true) {
          final List<dynamic> data = myPendingResponse['Data'] ?? [];
          int calculatedPending = 0;
          for (var item in data) {
            final request = _parseRequestFromAPI(item);
            if (request.status == request_models.RequestStatus.pending) {
              calculatedPending++;
            }
          }
          _myPendingRequestsCount = calculatedPending;
        } else {
          _myPendingRequestsCount = 0;
        }

        _isLoadingDashboard = false;
      });
    } catch (e) {
      _log('Data load error: $e');
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  // Copied helper from RequestsScreen
  request_models.EmployeeRequest _parseRequestFromAPI(
      Map<String, dynamic> json) {
    return request_models.EmployeeRequest(
      id: json['ID']?.toString() ?? '',
      requestNumber: json['RequestNumber']?.toString() ?? '',
      employeeId: json['EmployeeID']?.toString() ?? '',
      employeeName: json['EmployeeName']?.toString() ?? '',
      type: _parseRequestType(json['RequestTypeName']),
      title: json['RequestTypeName'] ?? '',
      description: json['Description']?.toString() ?? '',
      startDate: DateTime.tryParse(json['StartDate'] ?? '') ??
          DateTime.tryParse(json['CreatedDate'] ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(json['EndDate'] ?? '') ??
          DateTime.tryParse(json['CreatedDate'] ?? '') ??
          DateTime.now(),
      status: _parseRequestStatus(json['Status']),
      priority: json['Priority']?.toString() ?? 'Normal',
      createdAt: DateTime.tryParse(json['CreatedDate'] ?? '') ?? DateTime.now(),
      approvedBy: null,
      rejectionReason: null,
    );
  }

  request_models.RequestType _parseRequestType(String? typeName) {
    if (typeName?.contains('loan') == true ||
        typeName?.contains('سلفة') == true) {
      return request_models.RequestType.loan;
    } else if (typeName?.contains('leave') == true ||
        typeName?.contains('إجازة') == true) {
      return request_models.RequestType.leave;
    }
    return request_models.RequestType.other;
  }

  request_models.RequestStatus _parseRequestStatus(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'pending':
      case 'بانتظار الموافقة':
      case 'draft':
        return request_models.RequestStatus.pending;
      case 'approved':
      case 'معتمد':
        return request_models.RequestStatus.approved;
      case 'rejected':
      case 'مرفوض':
        return request_models.RequestStatus.rejected;
      case 'cancelled':
      case 'cancelled':
      case 'ملغي':
        return request_models.RequestStatus.cancelled;
      default:
        return request_models.RequestStatus.pending;
    }
  }

  void _checkDocumentExpiry({bool updateState = true}) {
    // ... existing logic ...
    // Keeping minimal logic here for brevity in rewrite, assuming original logic is preserved if I don't touch it?
    // Wait, I am overwriting the file. I MUST include the logic.
    if (employeeFullInfo == null) return;
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final now = DateTime.now();
    final notifications = <String>[];

    if (employeeFullInfo!.nationalIdExpiryDate.isNotEmpty) {
      try {
        final expiryDate =
            DateTime.parse(employeeFullInfo!.nationalIdExpiryDate);
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        if (daysUntilExpiry < 0) {
          notifications
              .add('⚠️ ${Translations.getText('national_id_expired', lang)}');
        } else if (daysUntilExpiry <= 60) {
          notifications.add(
              '⚠️ ${Translations.getTextWithParams('national_id_expiring', lang, {
                'days': daysUntilExpiry.toString()
              })}');
        }
      } catch (e) {}
    }
    if (employeeFullInfo!.passportExpiryDate.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(employeeFullInfo!.passportExpiryDate);
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        if (daysUntilExpiry < 0) {
          notifications
              .add('⚠️ ${Translations.getText('passport_expired', lang)}');
        } else if (daysUntilExpiry <= 60) {
          notifications.add(
              '⚠️ ${Translations.getTextWithParams('passport_expiring', lang, {
                'days': daysUntilExpiry.toString()
              })}');
        }
      } catch (e) {}
    }

    if (updateState) {
      setState(() {
        expiryNotifications = notifications;
      });
    } else {
      expiryNotifications = notifications;
    }

    if (notifications.isNotEmpty) {
      // Defer dialog show to next frame to avoid "setState during build" or similar issues if called from init
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showExpiryNotifications(notifications);
      });
    }
  }

  void _showExpiryNotifications(List<String> notifications) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(Translations.getText('document_expiry_warning', lang)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: notifications
              .map((notification) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(notification,
                        overflow: TextOverflow.ellipsis, maxLines: 3),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(Translations.getText('close', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // ... existing logout logic ...
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.getText('logout', lang)),
        content: Text(Translations.getText('confirm_logout', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(Translations.getText('cancel', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(Translations.getText('confirm', lang)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      try {
        await ApiService.logout();
      } catch (e) {}

      // مسح بيانات الجلسة المحفوظة
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      await prefs.setBool('is_logged_in', false);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;

    if (_currentEmployee == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.getText('dashboard', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  employee: _currentEmployee!,
                  clientId: widget.employeeData?.clientID ?? 30,
                ),
              ),
            );
          },
        ),
        actions: [
          // Notification Icon
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(
                        clientId: widget.employeeData?.clientID ?? 30,
                        employeeId: widget.employeeData!.employeeID,
                        employeeNumber: widget.employeeData!.employeeNumber,
                      ),
                    ),
                  );
                  // Refresh dashboard when coming back (to update unread count)
                  _loadAllData();
                },
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationsCount > 99
                          ? '99+'
                          : _unreadNotificationsCount.toString(),
                      style: TextStyle(
                          color: scheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          /*  IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    employee: _currentEmployee!,
                    clientId: widget.employeeData?.clientID ?? 30,
                  ),
                ),
              );
            },
          ),*/
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAllData();
        },
        child: ResponsiveCenter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(lang),
                const SizedBox(height: 24),
                _buildAttendanceCard(lang),
                const SizedBox(height: 24),
                _buildQuickActions(lang),
                const SizedBox(height: 24),
                _buildRecentRequestsCard(lang),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... _buildWelcomeCard and _buildAttendanceCard are same ...
  Widget _buildWelcomeCard(String lang) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.onPrimary.withOpacity(0.18),
            child: Icon(Icons.person, size: 35, color: scheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translations.getTextWithParams(
                      'welcome_user', lang, {'name': _currentEmployee!.name}),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                ),
                Text(
                  _currentEmployee!.position,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimary.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(String lang) {
    final hasCheckedIn = _attendanceStats['hasCheckedIn'] ?? false;
    final hasCheckedOut = _attendanceStats['hasCheckedOut'] ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: scheme.primary),
                const SizedBox(width: 8),
                Text(Translations.getText('today_attendance', lang),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAttendanceButton(
                    title: Translations.getText('check_in', lang),
                    icon: Icons.login,
                    isEnabled: !hasCheckedIn,
                    tone: _AttendanceTone.primary,
                    onPressed:
                        hasCheckedIn ? null : () => _navigateToAttendance(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAttendanceButton(
                    title: Translations.getText('check_out', lang),
                    icon: Icons.logout,
                    isEnabled: !hasCheckedOut,
                    tone: _AttendanceTone.secondary,
                    onPressed: hasCheckedOut
                        ? null
                        : () => _navigateToAttendance(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAttendance(bool isCheckIn) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AttendanceScreen(
                employeeNumber: _currentEmployee!.employeeNumber,
                clientId: widget.employeeData?.clientID ?? 1,
                isCheckIn: isCheckIn)));
  }

  Widget _buildAttendanceButton({
    required String title,
    required IconData icon,
    required bool isEnabled,
    required _AttendanceTone tone,
    VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg =
        tone == _AttendanceTone.primary ? scheme.primary : scheme.secondary;
    return FilledButton(
      onPressed: isEnabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(String lang) {
    final scheme = Theme.of(context).colorScheme;
    // final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    if (semantic == null) return const SizedBox();
    final isApprover =
        widget.employeeData?.rules.toLowerCase().contains('approver') == true ||
            widget.employeeData?.rules.toLowerCase().contains('مدير') == true ||
            widget.employeeData?.rules.toLowerCase().contains('رئيس') == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Translations.getText('quick_actions', lang),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              title: Translations.getText('my_requests', lang),
              icon: Icons.assignment,
              color: scheme.primary,
              // Use the greater of: parsed pending counts OR actual pending requests from list API
              badgeCount: ((_pendingCounts?.loan ?? 0) +
                          (_pendingCounts?.leave ?? 0) +
                          (_pendingCounts?.other ?? 0)) >
                      _myPendingRequestsCount
                  ? ((_pendingCounts?.loan ?? 0) +
                      (_pendingCounts?.leave ?? 0) +
                      (_pendingCounts?.other ?? 0))
                  : _myPendingRequestsCount,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RequestsScreen(
                            employeeId: widget.employeeId,
                            employeeData: widget.employeeData!)));
                _loadAllData();
              },
            ),
            _buildActionCard(
              title: Translations.getText('attendance_history', lang),
              icon: Icons.history,
              color: semantic.success,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AttendanceHistoryScreen(
                            employeeNumber: _currentEmployee!.employeeNumber,
                            clientId: widget.employeeData?.clientID ?? 30,
                            employeeName: _currentEmployee!.name)));
                _loadAllData();
              },
            ),
            if (isApprover)
              _buildActionCard(
                title: Translations.getText('approvals', lang),
                icon: Icons.approval,
                color: scheme.secondary,
                badgeCount: _pendingApprovalsCount,
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ApprovalsScreen(
                              employeeId: widget.employeeId,
                              employeeData: widget.employeeData!)));
                  _loadAllData();
                },
              ),
            _buildActionCard(
              title: Translations.getText('shifts_and_location', lang),
              icon: Icons.work_history,
              color: scheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShiftInfoScreen(
                    clientId: widget.employeeData!.clientID,
                    employeeNumber: widget.employeeData!.employeeNumber,
                    email: widget.employeeData!.email,
                    employeeId: widget.employeeData!.employeeID,
                  ),
                ),
              ),
            ),
            _buildActionCard(
              title: Translations.getText('salary_details_title', lang),
              icon: Icons.payments,
              color: scheme.tertiary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SalaryDetailsScreen(
                    employeeId: widget.employeeData!.employeeID,
                    clientId: widget.employeeData!.clientID,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -8,
              right:
                  -8, // Changed from left to right for better RTL support (Start in RTL, End in LTR)
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: semantic.warning,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  '$badgeCount ${Translations.getText('pending', lang)}',
                  style: TextStyle(
                    color: semantic.onWarning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsCard(String lang) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Translations.getText('my_requests', lang),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_recentRequests.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  Translations.getText('no_recent_requests', lang),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          )
        else
          ..._recentRequests
              .map((request) => _buildRequestItem(request))
              .toList(),
      ],
    );
  }

  Widget _buildRequestItem(request_models.EmployeeRequest request) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    Color statusColor;
    String statusText;
    switch (request.status) {
      case request_models.RequestStatus.pending:
        statusColor = semantic.warning;
        statusText = Translations.getText('pending', lang);
        break;
      case request_models.RequestStatus.approved:
        statusColor = semantic.success;
        statusText = Translations.getText('approved', lang);
        break;
      case request_models.RequestStatus.rejected:
        statusColor = scheme.error;
        statusText = Translations.getText('rejected', lang);
        break;
      case request_models.RequestStatus.cancelled:
        statusColor = scheme.outline;
        statusText = Translations.getText('cancelled', lang);
        break;
      default:
        statusColor = scheme.outline;
        statusText = Translations.getText('unknown', lang);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(_getRequestTypeIcon(request.type), size: 20),
        ),
        title:
            Text(request.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatDate(request.createdAt)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            statusText,
            style: TextStyle(
                color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        onTap: () => _showRequestDetails(request),
      ),
    );
  }

  IconData _getRequestTypeIcon(request_models.RequestType type) {
    switch (type) {
      case request_models.RequestType.loan:
        return Icons.account_balance;
      case request_models.RequestType.leave:
        return Icons.beach_access;
      case request_models.RequestType.overtime:
        return Icons.access_time;
      case request_models.RequestType.sick:
        return Icons.local_hospital;
      case request_models.RequestType.vacation:
        return Icons.flight;
      default:
        return Icons.assignment;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Copied from RequestsScreen
  void _showRequestDetails(request_models.EmployeeRequest request) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.getRequestDetails(
        widget.employeeData!.clientID,
        int.parse(request.id),
      );
      Navigator.of(context).pop();
      final details = response['Success'] == true ? response['Data'] : null;
      _showRequestDetailsDialog(request, details);
    } catch (e) {
      Navigator.of(context).pop();
      _showRequestDetailsDialog(request, null);
    }
  }

  void _showRequestDetailsDialog(
      request_models.EmployeeRequest request, Map<String, dynamic>? details) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    String statusText;
    switch (request.status) {
      case request_models.RequestStatus.pending:
        statusText = Translations.getText('pending', lang);
        break;
      case request_models.RequestStatus.approved:
        statusText = Translations.getText('approved', lang);
        break;
      case request_models.RequestStatus.rejected:
        statusText = Translations.getText('rejected', lang);
        break;
      case request_models.RequestStatus.cancelled:
        statusText = Translations.getText('cancelled', lang);
        break;
      default:
        statusText = Translations.getText('unknown', lang);
    }

    // simplified dialog reuse
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(request.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "${Translations.getText('request_number', lang)}: ${request.requestNumber}"),
                Text("${Translations.getText('status', lang)}: $statusText"),
                if (details != null) ...[
                  const Divider(),
                  Text("${Translations.getText('additional_details', lang)}:"),
                  // ... render details ...
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(Translations.getText('close', lang)))
          ],
        );
      },
    );
  }
}

enum _AttendanceTone { primary, secondary }
