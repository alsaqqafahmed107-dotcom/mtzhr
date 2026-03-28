import 'employee_full_info.dart';
import 'shift.dart';

class EmployeeInfo {
  final String name;
  final String qualification;
  final String department;
  final String position;

  EmployeeInfo({
    required this.name,
    this.qualification = '',
    this.department = '',
    this.position = '',
  });

  factory EmployeeInfo.fromEmployeeFullInfo(EmployeeFullInfo info) {
    return EmployeeInfo(
      name: info.fullName,
      qualification: info.qualification ?? '',
      department: info.departmentName ?? '',
      position: info.positionName ?? info.positionId,
    );
  }

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) {
    String pickString(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
      return '';
    }

    return EmployeeInfo(
      name: pickString(['EmployeeName', 'employeeName', 'Name', 'name']),
      qualification: pickString(['Qualification', 'qualification']),
      department: pickString(['DepartmentName', 'departmentName', 'Department', 'department']),
      position: pickString(['PositionName', 'positionName', 'Position', 'position', 'PositionID', 'positionId']),
    );
  }
}

class ShiftInfo {
  final String name;
  final String dailyStartTime;
  final String dailyEndTime;
  final DateTime assignmentStartDate;
  final DateTime? assignmentEndDate;
  final bool isFlexible;
  final bool isNightShift;
  final int gracePeriodMinutes;

  ShiftInfo({
    required this.name,
    required this.dailyStartTime,
    required this.dailyEndTime,
    required this.assignmentStartDate,
    this.assignmentEndDate,
    this.isFlexible = false,
    this.isNightShift = false,
    this.gracePeriodMinutes = 0,
  });

  factory ShiftInfo.fromShiftData(ShiftData shift) {
    DateTime parseDate(String? value) {
      final normalized = (value ?? '').trim();
      return DateTime.tryParse(normalized) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime? parseNullableDate(String? value) {
      final normalized = (value ?? '').trim();
      if (normalized.isEmpty || normalized == 'مستمر') return null;
      return DateTime.tryParse(normalized);
    }

    return ShiftInfo(
      name: shift.shiftName,
      dailyStartTime: shift.defaultStartTime,
      dailyEndTime: shift.defaultEndTime,
      assignmentStartDate: parseDate(shift.assignmentStartDate ?? shift.effectiveFrom),
      assignmentEndDate: parseNullableDate(shift.assignmentEndDate ?? shift.effectiveTo),
      isFlexible: shift.isFlexible,
      isNightShift: shift.isNightShift,
      gracePeriodMinutes: shift.graceInMinutes,
    );
  }
}

class WorkDay {
  final String dayName;
  final bool isWorkingDay;
  final String? startTime;
  final String? endTime;

  WorkDay({
    required this.dayName,
    required this.isWorkingDay,
    this.startTime,
    this.endTime,
  });

  factory WorkDay.fromShiftWorkDay(ShiftWorkDay day) {
    return WorkDay(
      dayName: day.dayName,
      isWorkingDay: day.isWorkDay,
      startTime: day.workStartTime,
      endTime: day.workEndTime,
    );
  }

  String get displayTimeRange {
    if (!isWorkingDay) return 'إجازة';
    final s = (startTime ?? '').trim();
    final e = (endTime ?? '').trim();
    if (s.isEmpty && e.isEmpty) return '';
    if (s.isEmpty) return e;
    if (e.isEmpty) return s;
    return '$s - $e';
  }
}
