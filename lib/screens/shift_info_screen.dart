import 'package:flutter/material.dart';
import 'package:smart_vision/models/employee_full_info.dart';
import 'package:smart_vision/models/shift.dart';
import 'package:smart_vision/models/work_info_models.dart';
import 'package:smart_vision/models/location.dart';
import 'package:smart_vision/services/api_service.dart';
import 'package:smart_vision/widgets/responsive_center.dart';
import 'package:smart_vision/services/language_service.dart';
import 'package:smart_vision/services/translations.dart';
import 'package:provider/provider.dart';

class ShiftInfoScreen extends StatefulWidget {
  final int clientId;
  final String employeeNumber;
  final String email;
  final int? employeeId;

  const ShiftInfoScreen({
    super.key,
    required this.clientId,
    required this.employeeNumber,
    required this.email,
    this.employeeId,
  });

  @override
  State<ShiftInfoScreen> createState() => _ShiftInfoScreenState();
}

class _ShiftInfoScreenState extends State<ShiftInfoScreen> {
  bool _isLoading = true;
  String? _error;
  String? _shiftNotice;
  EmployeeFullInfo? _employeeInfo;
  List<ShiftData> _shifts = [];
  List<EmployeeAssignedLocation> _assignedLocations = [];
  String? _locationsNotice;

  ShiftData? get _currentShift {
    if (_shifts.isEmpty) return null;
    final active = _shifts.where((s) => s.isActive).toList();
    return active.isNotEmpty ? active.first : _shifts.first;
  }

  ShiftInfo? get _currentShiftInfo =>
      _currentShift == null ? null : ShiftInfo.fromShiftData(_currentShift!);

  List<WorkDay> get _workDays =>
      (_currentShift?.workDays ?? []).map(WorkDay.fromShiftWorkDay).toList();

  String? _weekdayKeyFrom(int dayNumber, String rawName) {
    final normalized = rawName
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), '');

    final byName = <String, String>{
      'الاحد': 'weekday_sunday',
      'الأحد': 'weekday_sunday',
      'احد': 'weekday_sunday',
      'الاثنين': 'weekday_monday',
      'الإثنين': 'weekday_monday',
      'اثنين': 'weekday_monday',
      'الثلاثاء': 'weekday_tuesday',
      'الثلاثا': 'weekday_tuesday',
      'ثلاثاء': 'weekday_tuesday',
      'الاربعاء': 'weekday_wednesday',
      'الأربعاء': 'weekday_wednesday',
      'اربعاء': 'weekday_wednesday',
      'الخميس': 'weekday_thursday',
      'خميس': 'weekday_thursday',
      'الجمعة': 'weekday_friday',
      'جمعه': 'weekday_friday',
      'السبت': 'weekday_saturday',
      'سبت': 'weekday_saturday',
      'sunday': 'weekday_sunday',
      'sun': 'weekday_sunday',
      'monday': 'weekday_monday',
      'mon': 'weekday_monday',
      'tuesday': 'weekday_tuesday',
      'tue': 'weekday_tuesday',
      'wednesday': 'weekday_wednesday',
      'wed': 'weekday_wednesday',
      'thursday': 'weekday_thursday',
      'thu': 'weekday_thursday',
      'friday': 'weekday_friday',
      'fri': 'weekday_friday',
      'saturday': 'weekday_saturday',
      'sat': 'weekday_saturday',
    };

    if (byName.containsKey(normalized)) {
      return byName[normalized];
    }

    if (dayNumber >= 1 && dayNumber <= 7) {
      const byNumber = <int, String>{
        1: 'weekday_sunday',
        2: 'weekday_monday',
        3: 'weekday_tuesday',
        4: 'weekday_wednesday',
        5: 'weekday_thursday',
        6: 'weekday_friday',
        7: 'weekday_saturday',
      };
      return byNumber[dayNumber];
    }

    return null;
  }

  String _localizedWeekdayName(WorkDay day, String lang) {
    final key = _weekdayKeyFrom(day.dayNumber, day.dayName);
    if (key == null) return day.dayName;
    return Translations.getText(key, lang);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _shiftNotice = null;
      _locationsNotice = null;
    });

    try {
      final employeeInfo =
          await ApiService().getEmployeeFullInfo(widget.clientId, widget.email);
      final locations = await ApiService.getEmployeeAssignedLocations(
        widget.clientId,
        widget.employeeNumber,
      );
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      final locationsNotice = locations.isEmpty
          ? Translations.getText('no_location_assigned', lang)
          : null;

      final identifiers = <String?>[
        widget.employeeNumber,
        widget.employeeId?.toString(),
      ].where((v) => v != null && v!.trim().isNotEmpty).toSet().toList();

      List<ShiftData> shifts = [];
      for (final identifier in identifiers) {
        shifts = await ApiService.getEmployeeShift(widget.clientId, identifier);
        if (shifts.isNotEmpty) break;
      }
      final shiftNotice =
          shifts.isEmpty ? ApiService.lastEmployeeShiftMessage : null;

      if (!mounted) return;
      setState(() {
        _employeeInfo = employeeInfo;
        _assignedLocations = locations;
        _locationsNotice = locationsNotice;
        _shifts = shifts;
        _shiftNotice = shiftNotice;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      setState(() {
        _error = '${Translations.getText('error_loading_data', lang)}: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.getText('work_information', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ResponsiveCenter(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    if (_error != null) ...[
                      _buildErrorCard(_error!),
                      const SizedBox(height: 16),
                    ],
                    _buildLocationsCard(),
                    const SizedBox(height: 16),
                    _buildShiftCard(),
                    const SizedBox(height: 16),
                    _buildWorkDaysCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorCard(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onErrorContainer),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard() {
    final shiftInfo = _currentShiftInfo;
    final isNight = shiftInfo?.isNightShift == true;
    final scheme = Theme.of(context).colorScheme;

    if (shiftInfo == null) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      return _emptyCard(
        icon: Icons.info_outline,
        title: _shiftNotice?.trim().isNotEmpty == true
            ? _shiftNotice!
            : Translations.getText('no_shift_assigned', lang),
      );
    }

    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final hireDateText = _employeeInfo?.hireDate.trim().isNotEmpty == true
        ? _formatRawDate(_employeeInfo!.hireDate)
        : Translations.getText('not_specified', lang);
    final endDateText = _employeeInfo?.contractEndDate.trim().isNotEmpty == true
        ? _formatRawDate(_employeeInfo!.contractEndDate)
        : Translations.getText('ongoing', lang);

    final cardColor = isNight ? scheme.primaryContainer : scheme.surface;
    final fg = isNight ? scheme.onPrimaryContainer : scheme.onSurface;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isNight
                        ? scheme.primary.withOpacity(0.12)
                        : scheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.access_time, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shiftInfo.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: fg,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _kvRow(
              icon: Icons.schedule,
              label: Translations.getText('primary_shift_period', lang),
              value: _formatShiftTime(_currentShift!),
              inverse: isNight,
            ),
            if (_hasSecondShiftPeriod(_currentShift!)) ...[
              const SizedBox(height: 10),
              _kvRow(
                icon: Icons.schedule_outlined,
                label: Translations.getText('secondary_shift_period', lang),
                value: _formatSecondShiftTime(_currentShift!),
                inverse: isNight,
              ),
            ],
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.date_range,
              label: Translations.getText('hire_date', lang),
              value: hireDateText,
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.event_busy,
              label: Translations.getText('assignment_end', lang),
              value: endDateText,
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.swap_horiz,
              label: Translations.getText('flexible_system', lang),
              value: shiftInfo.isFlexible
                  ? Translations.getText('yes', lang)
                  : Translations.getText('no', lang),
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.nights_stay,
              label: Translations.getText('night_shift', lang),
              value: shiftInfo.isNightShift
                  ? Translations.getText('yes', lang)
                  : Translations.getText('no', lang),
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.timer,
              label: Translations.getText('grace_period', lang),
              value:
                  '${shiftInfo.gracePeriodMinutes} ${Translations.getText('minutes', lang)}',
              inverse: isNight,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllShiftsScreen(
                        clientId: widget.clientId,
                        employeeNumber: widget.employeeNumber,
                        email: widget.email,
                        employeeId: widget.employeeId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: Text(Translations.getText('view_all_shifts', lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationsCard() {
    if (_assignedLocations.isEmpty) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      return _emptyCard(
        icon: Icons.location_on_outlined,
        title: _locationsNotice?.trim().isNotEmpty == true
            ? _locationsNotice!
            : Translations.getText('no_location_assigned', lang),
      );
    }

    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  Translations.getText('location', lang),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ..._assignedLocations.map((loc) {
              final address = (loc.locationAddress ?? '').trim();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      loc.isActive ? Icons.place : Icons.place_outlined,
                      color: loc.isActive ? scheme.primary : scheme.outline,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.locationName.isNotEmpty
                                ? loc.locationName
                                : '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              address,
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (loc.radiusMeters != null && loc.radiusMeters! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${loc.radiusMeters}م',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkDaysCard() {
    final days = _workDays;
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    if (_currentShift == null) {
      return _emptyCard(
        icon: Icons.calendar_month,
        title: Translations.getText('no_work_days', lang),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  Translations.getText('work_days', lang),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                Translations.getText('no_work_days', lang),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (_, index) {
                final day = days[index];
                final isWorking = day.isWorkingDay;
                final statusColor = isWorking ? Colors.green : scheme.error;
                final statusTextColor =
                    isWorking ? scheme.onSurface : scheme.onSurfaceVariant;
                final dayName = _localizedWeekdayName(day, lang);
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(isWorking ? Icons.check_circle : Icons.cancel,
                          color: statusColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isWorking ? FontWeight.bold : FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                      Text(
                        day.displayTimeRange.isNotEmpty
                            ? day.displayTimeRange
                            : (isWorking
                                ? '-'
                                : Translations.getText('status_holiday', lang)),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isWorking
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _kvRow({
    required IconData icon,
    required String label,
    required String value,
    required bool inverse,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = inverse
        ? scheme.onPrimaryContainer.withOpacity(0.85)
        : scheme.onSurfaceVariant;
    final valueColor = inverse ? scheme.onPrimaryContainer : scheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: inverse ? scheme.primary : scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 14, color: labelColor, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 14, color: valueColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _emptyCard({required IconData icon, required String title}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 46, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatRawDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return normalized;
    return _formatDate(parsed);
  }

  String _formatShiftTime(ShiftData shift) {
    final timeRange = (shift.timeRange ?? '').trim();
    if (timeRange.isNotEmpty) return timeRange;

    final startLabel = (shift.startTimeLabel ?? '').trim();
    final endLabel = (shift.endTimeLabel ?? '').trim();
    if (startLabel.isNotEmpty && endLabel.isNotEmpty) {
      return '$startLabel - $endLabel';
    }

    final start = shift.defaultStartTime.trim();
    final end = shift.defaultEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '-';
  }

  bool _hasSecondShiftPeriod(ShiftData shift) {
    return shift.secondStartTime.trim().isNotEmpty ||
        shift.secondEndTime.trim().isNotEmpty;
  }

  String _formatSecondShiftTime(ShiftData shift) {
    final start = shift.secondStartTime.trim();
    final end = shift.secondEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '-';
  }
}

class AllShiftsScreen extends StatefulWidget {
  final int clientId;
  final String employeeNumber;
  final String email;
  final int? employeeId;

  const AllShiftsScreen({
    super.key,
    required this.clientId,
    required this.employeeNumber,
    required this.email,
    this.employeeId,
  });

  @override
  State<AllShiftsScreen> createState() => _AllShiftsScreenState();
}

class _AllShiftsScreenState extends State<AllShiftsScreen> {
  bool _isLoading = true;
  String? _error;
  EmployeeFullInfo? _employeeInfo;
  List<ShiftData> _shifts = [];
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _notice = null;
    });

    try {
      final employeeInfo =
          await ApiService().getEmployeeFullInfo(widget.clientId, widget.email);
      final identifiers = <String?>[
        widget.employeeNumber,
        widget.employeeId?.toString(),
      ].where((v) => v != null && v!.trim().isNotEmpty).toList();

      List<ShiftData> shifts = [];
      for (final identifier in identifiers) {
        shifts =
            await ApiService.getEmployeeShiftsAll(widget.clientId, identifier);
        if (shifts.isNotEmpty) break;
      }

      if (!mounted) return;
      setState(() {
        _employeeInfo = employeeInfo;
        _shifts = shifts;
        _notice = shifts.isEmpty ? ApiService.lastEmployeeShiftMessage : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      setState(() {
        _error = '${Translations.getText('error_loading_shifts', lang)}: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.getText('all_shifts', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _shifts.isEmpty
                      ? ResponsiveCenter(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Center(
                                child: Text(
                                  _notice?.trim().isNotEmpty == true
                                      ? _notice!
                                      : Translations.getText(
                                          'no_shifts_available', lang),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ResponsiveCenter(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _shifts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final scheme = Theme.of(context).colorScheme;
                              final shift = _shifts[index];
                              final info = ShiftInfo.fromShiftData(shift);
                              final hireDateText =
                                  _employeeInfo?.hireDate.trim().isNotEmpty ==
                                          true
                                      ? _formatRawDate(_employeeInfo!.hireDate)
                                      : Translations.getText(
                                          'not_specified', lang);
                              final endDateText = _employeeInfo
                                          ?.contractEndDate
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? _formatRawDate(
                                      _employeeInfo!.contractEndDate)
                                  : Translations.getText('ongoing', lang);
                              final isNight = info.isNightShift;
                              final bg = isNight
                                  ? scheme.primaryContainer
                                  : scheme.surface;
                              final fg = isNight
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface;
                              final sub = isNight
                                  ? scheme.onPrimaryContainer.withOpacity(0.85)
                                  : scheme.onSurfaceVariant;
                              return Card(
                                color: bg,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              color: scheme.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              info.name,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: fg),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: scheme.primary
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              shift.isActive
                                                  ? Translations.getText(
                                                      'active', lang)
                                                  : Translations.getText(
                                                      'inactive', lang),
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: fg),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${Translations.getText('primary_shift_period', lang)}: ${_formatShiftTime(shift)}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: sub),
                                          ),
                                          if (_hasSecondShiftPeriod(shift)) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${Translations.getText('secondary_shift_period', lang)}: ${_formatSecondShiftTime(shift)}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: sub),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${Translations.getText('hire_date', lang)}: $hireDateText',
                                        style: TextStyle(color: sub),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${Translations.getText('assignment_end', lang)}: $endDateText',
                                        style: TextStyle(color: sub),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
    );
  }

  String _formatRawDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return normalized;

    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatShiftTime(ShiftData shift) {
    final timeRange = (shift.timeRange ?? '').trim();
    if (timeRange.isNotEmpty) return timeRange;

    final startLabel = (shift.startTimeLabel ?? '').trim();
    final endLabel = (shift.endTimeLabel ?? '').trim();
    if (startLabel.isNotEmpty && endLabel.isNotEmpty) {
      return '$startLabel - $endLabel';
    }

    final start = shift.defaultStartTime.trim();
    final end = shift.defaultEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '-';
  }

  bool _hasSecondShiftPeriod(ShiftData shift) {
    return shift.secondStartTime.trim().isNotEmpty ||
        shift.secondEndTime.trim().isNotEmpty;
  }

  String _formatSecondShiftTime(ShiftData shift) {
    final start = shift.secondStartTime.trim();
    final end = shift.secondEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    if (start.isNotEmpty) return start;
    if (end.isNotEmpty) return end;
    return '-';
  }
}
