import 'package:flutter/material.dart';
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
      final locations = await ApiService.getEmployeeAssignedLocations(
        widget.clientId,
        widget.employeeNumber,
      );
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      final locationsNotice = locations.isEmpty ? Translations.getText('no_location_assigned', lang) : null;

      final identifiers = <String?>[
        widget.employeeNumber,
        widget.employeeId?.toString(),
      ]
          .where((v) => v != null && v!.trim().isNotEmpty)
          .toSet()
          .toList();

      List<ShiftData> shifts = [];
      for (final identifier in identifiers) {
        shifts = await ApiService.getEmployeeShift(widget.clientId, identifier);
        if (shifts.isNotEmpty) break;
      }
      final shiftNotice = shifts.isEmpty ? ApiService.lastEmployeeShiftMessage : null;

      if (!mounted) return;
      setState(() {
        _assignedLocations = locations;
        _locationsNotice = locationsNotice;
        _shifts = shifts;
        _shiftNotice = shiftNotice;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final languageService = Provider.of<LanguageService>(context, listen: false);
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onErrorContainer),
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
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      return _emptyCard(
        icon: Icons.info_outline,
        title: _shiftNotice?.trim().isNotEmpty == true
            ? _shiftNotice!
            : Translations.getText('no_shift_assigned', lang),
      );
    }

    final languageService = Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final start = shiftInfo.assignmentStartDate;
    final end = shiftInfo.assignmentEndDate;
    final startText = _formatDate(start);
    final endText = end == null ? Translations.getText('ongoing', lang) : _formatDate(end);

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
                    color: isNight ? scheme.primary.withOpacity(0.12) : scheme.primary.withOpacity(0.10),
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
              label: Translations.getText('shift_time', lang),
              value: '${shiftInfo.dailyStartTime} - ${shiftInfo.dailyEndTime}',
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.date_range,
              label: Translations.getText('assignment_start', lang),
              value: startText,
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.event_busy,
              label: Translations.getText('assignment_end', lang),
              value: endText,
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.swap_horiz,
              label: Translations.getText('flexible_system', lang),
              value: shiftInfo.isFlexible ? Translations.getText('yes', lang) : Translations.getText('no', lang),
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.nights_stay,
              label: Translations.getText('night_shift', lang),
              value: shiftInfo.isNightShift ? Translations.getText('yes', lang) : Translations.getText('no', lang),
              inverse: isNight,
            ),
            const SizedBox(height: 10),
            _kvRow(
              icon: Icons.timer,
              label: Translations.getText('grace_period', lang),
              value: '${shiftInfo.gracePeriodMinutes} ${Translations.getText('minutes', lang)}',
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
      final languageService = Provider.of<LanguageService>(context, listen: false);
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                            loc.locationName.isNotEmpty ? loc.locationName : '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              address,
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (loc.radiusMeters != null && loc.radiusMeters! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    final languageService = Provider.of<LanguageService>(context, listen: false);
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (_, index) {
                final day = days[index];
                final isWorking = day.isWorkingDay;
                final statusColor = isWorking ? scheme.tertiary : scheme.error;
                final statusTextColor = isWorking ? scheme.onSurface : scheme.onSurfaceVariant;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(isWorking ? Icons.check_circle : Icons.cancel, color: statusColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          day.dayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isWorking ? FontWeight.bold : FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                      Text(
                        day.displayTimeRange.isNotEmpty ? day.displayTimeRange : (isWorking ? '-' : Translations.getText('status_holiday', lang)),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isWorking ? scheme.primary : scheme.onSurfaceVariant,
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
    final labelColor = inverse ? scheme.onPrimaryContainer.withOpacity(0.85) : scheme.onSurfaceVariant;
    final valueColor = inverse ? scheme.onPrimaryContainer : scheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 18, color: inverse ? scheme.primary : scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: labelColor, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: valueColor, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
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
}

class AllShiftsScreen extends StatefulWidget {
  final int clientId;
  final String employeeNumber;
  final int? employeeId;

  const AllShiftsScreen({
    super.key,
    required this.clientId,
    required this.employeeNumber,
    this.employeeId,
  });

  @override
  State<AllShiftsScreen> createState() => _AllShiftsScreenState();
}

class _AllShiftsScreenState extends State<AllShiftsScreen> {
  bool _isLoading = true;
  String? _error;
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
      final identifiers = <String?>[
        widget.employeeNumber,
        widget.employeeId?.toString(),
      ].where((v) => v != null && v!.trim().isNotEmpty).toList();

      List<ShiftData> shifts = [];
      for (final identifier in identifiers) {
        shifts = await ApiService.getEmployeeShiftsAll(widget.clientId, identifier);
        if (shifts.isNotEmpty) break;
      }

      if (!mounted) return;
      setState(() {
        _shifts = shifts;
        _notice = shifts.isEmpty ? ApiService.lastEmployeeShiftMessage : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final languageService = Provider.of<LanguageService>(context, listen: false);
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
                                    _notice?.trim().isNotEmpty == true ? _notice! : Translations.getText('no_shifts_available', lang),
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, index) {
                                final scheme = Theme.of(context).colorScheme;
                                final shift = _shifts[index];
                                final info = ShiftInfo.fromShiftData(shift);
                                final isNight = info.isNightShift;
                                final bg = isNight ? scheme.primaryContainer : scheme.surface;
                                final fg = isNight ? scheme.onPrimaryContainer : scheme.onSurface;
                                final sub = isNight ? scheme.onPrimaryContainer.withOpacity(0.85) : scheme.onSurfaceVariant;
                                return Card(
                                  color: bg,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, color: scheme.primary),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                info.name,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: fg),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: scheme.primary.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                shift.isActive ? Translations.getText('active', lang) : Translations.getText('inactive', lang),
                                                style: TextStyle(fontWeight: FontWeight.bold, color: fg),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${info.dailyStartTime} - ${info.dailyEndTime}',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: sub),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${Translations.getText('start', lang)}: ${info.assignmentStartDate.year.toString().padLeft(4, '0')}-${info.assignmentStartDate.month.toString().padLeft(2, '0')}-${info.assignmentStartDate.day.toString().padLeft(2, '0')}',
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
}
