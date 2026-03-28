class ShiftData {
  final int shiftId;
  final String shiftName;
  final String? shiftCode;
  final String defaultStartTime;
  final String defaultEndTime;
  final String effectiveFrom;
  final String? effectiveTo;
  final bool isNightShift;
  final bool isFlexible;
  final double minWorkHours;
  final int graceInMinutes;
  final int graceOutMinutes;
  final String? shiftDuration;
  final String? assignmentStartDate;
  final String? assignmentEndDate;
  final String? assignmentDuration;
  final String? startTimeLabel;
  final String? endTimeLabel;
  final String? timeRange;
  final bool isActive; // تم إضافة حقل الحالة
  final List<ShiftWorkDay> workDays;

  ShiftData({
    required this.shiftId,
    required this.shiftName,
    this.shiftCode,
    required this.defaultStartTime,
    required this.defaultEndTime,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isNightShift,
    required this.isFlexible,
    required this.minWorkHours,
    required this.graceInMinutes,
    required this.graceOutMinutes,
    this.shiftDuration,
    this.assignmentStartDate,
    this.assignmentEndDate,
    this.assignmentDuration,
    this.startTimeLabel,
    this.endTimeLabel,
    this.timeRange,
    this.isActive = true,
    required this.workDays,
  });

  factory ShiftData.fromJson(Map<String, dynamic> json) {
    final rawWorkDays = json['WorkDays'] ?? json['workDays'];
    final List<dynamic> workDaysList = rawWorkDays is List ? rawWorkDays : const [];

    return ShiftData(
      shiftId: json['ShiftID'] ?? json['shiftId'] ?? 0,
      shiftName: json['ShiftName'] ?? json['shiftName'] ?? '',
      shiftCode: json['ShiftCode'] ?? json['shiftCode'],
      defaultStartTime: json['StartTime1']?.toString() ??
          json['DefaultStartTime']?.toString() ??
          json['shift_start']?.toString() ??
          json['defaultStartTime']?.toString() ??
          '',
      defaultEndTime: json['EndTime1']?.toString() ??
          json['DefaultEndTime']?.toString() ??
          json['shift_end']?.toString() ??
          json['defaultEndTime']?.toString() ??
          '',
      effectiveFrom: json['EffectiveFromStr'] ??
          json['EffectiveFrom'] ??
          json['valid_from'] ??
          json['effectiveFromStr'] ??
          json['effectiveFrom'] ??
          '',
      effectiveTo: json['EffectiveToStr'] ??
          json['EffectiveTo'] ??
          json['valid_to'] ??
          json['effectiveToStr'] ??
          json['effectiveTo'],
      isNightShift: json['IsNightShift'] ?? json['isNightShift'] ?? false,
      isFlexible: json['IsFlexible'] ?? json['isFlexible'] ?? false,
      minWorkHours: (json['MinWorkHours'] ?? json['minWorkHours'] ?? 0).toDouble(),
      graceInMinutes: json['GracePeriod'] ?? json['gracePeriod'] ?? json['GraceInMinutes'] ?? json['graceInMinutes'] ?? 0,
      graceOutMinutes: json['GraceOutMinutes'] ?? json['graceOutMinutes'] ?? 0,
      shiftDuration: json['ShiftDuration'] ?? json['shiftDuration'],
      assignmentStartDate: json['AssignmentStartDate'] ?? json['assignmentStartDate'],
      assignmentEndDate: json['AssignmentEndDate'] ?? json['assignmentEndDate'],
      assignmentDuration: json['AssignmentDuration'] ?? json['assignmentDuration'],
      startTimeLabel: json['StartTimeLabel'] ?? json['startTimeLabel'],
      endTimeLabel: json['EndTimeLabel'] ?? json['endTimeLabel'],
      timeRange: json['ShiftTimeRange'] ?? json['shiftTimeRange'],
      isActive: json['IsActive'] ?? json['isActive'] ?? true,
      workDays: workDaysList
          .whereType<Map>()
          .map((e) => ShiftWorkDay.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ShiftWorkDay {
  final int dayNumber;
  final String dayName;
  final bool isWorkDay;
  final String? workStartTime;
  final String? workEndTime;
  final String? timeRange;
  
  // Helper to check if it is a weekend/off-day
  bool get isWeekend => !isWorkDay;
  
  // Helper to get formatted start time (e.g. remove seconds if needed)
  String get startTime => workStartTime ?? '-';
  String get endTime => workEndTime ?? '-';
  String get displayRange => timeRange ?? (isWorkDay ? '$startTime - $endTime' : 'إجازة');

  ShiftWorkDay({
    required this.dayNumber,
    required this.dayName,
    required this.isWorkDay,
    this.workStartTime,
    this.workEndTime,
    this.timeRange,
  });

  factory ShiftWorkDay.fromJson(Map<String, dynamic> json) {
    return ShiftWorkDay(
      dayNumber: json['DayNumber'] ?? json['dayNumber'] ?? 0,
      dayName: json['DayName'] ?? json['dayName'] ?? '',
      isWorkDay: json['IsWorkDay'] ?? json['isWorkDay'] ?? false,
      workStartTime: json['StartTime']?.toString() ?? json['shift_start']?.toString() ?? json['WorkStartTime']?.toString() ?? json['workStartTime']?.toString(),
      workEndTime: json['EndTime']?.toString() ?? json['shift_end']?.toString() ?? json['WorkEndTime']?.toString() ?? json['workEndTime']?.toString(),
      timeRange: json['TimeRange'] ?? json['time_range'] ?? json['timeRange'],
    );
  }
}
