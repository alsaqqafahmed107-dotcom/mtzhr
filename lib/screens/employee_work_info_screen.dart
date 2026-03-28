import 'package:flutter/material.dart';
import 'package:smart_vision/models/employee_full_info.dart';
import 'package:smart_vision/models/shift.dart';
import 'package:smart_vision/services/api_service.dart';
import 'package:smart_vision/utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeWorkInfoScreen extends StatefulWidget {
  final int clientId;
  final String employeeNumber;
  final String email;
  final int? employeeId; // New optional parameter

  const EmployeeWorkInfoScreen({
    Key? key,
    required this.clientId,
    required this.employeeNumber,
    required this.email,
    this.employeeId,
  }) : super(key: key);

  @override
  _EmployeeWorkInfoScreenState createState() => _EmployeeWorkInfoScreenState();
}

class _EmployeeWorkInfoScreenState extends State<EmployeeWorkInfoScreen> {
  bool _isLoading = true;
  String? _error;
  EmployeeFullInfo? _employeeInfo;
  List<ShiftData> _shifts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 Fetching employee info for: Email=${widget.email}, ClientID=${widget.clientId}');
      final employeeInfo =
          await ApiService().getEmployeeFullInfo(widget.clientId, widget.email);

      final identifiers = <String?>[
        employeeInfo.employeeNumber,
        employeeInfo.employeeId.toString(),
        widget.employeeNumber,
        widget.employeeId?.toString(),
      ].where((v) => v != null && v!.trim().isNotEmpty).toList();

      print('🔍 Shift identifiers to try: ${identifiers.join(", ")}');

      List<ShiftData> shifts = [];
      for (final identifier in identifiers) {
        shifts = await ApiService.getEmployeeShift(widget.clientId, identifier);
        if (shifts.isNotEmpty) {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _employeeInfo = employeeInfo;
          _shifts = shifts;
          _isLoading = false;

          if (_employeeInfo != null) {
            print('🔍 Employee Info Loaded: Name=${_employeeInfo!.fullName}, Position=${_employeeInfo!.positionName}, Qual=${_employeeInfo!.qualification}');
          }
        });
      }
    } catch (e) {
      print('💥 Error in _loadData: $e');
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ أثناء تحميل البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('معلومات العمل',
            style:
                TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // Print functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(fontFamily: 'Tajawal')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // القسم 1: معلومات الموظف
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      // القسم 2: الورديات الحالية
                      if (_shifts.isNotEmpty) ...[
                        ..._shifts
                            .map((shift) => Column(
                                  children: [
                                    _buildCurrentShiftCard(shift),
                                    const SizedBox(height: 20),
                                    _buildWorkingDaysCard(shift),
                                    const SizedBox(height: 20),
                                  ],
                                ))
                            .toList(),
                      ] else
                        _buildEmptyShiftCard(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 15),
            Text(
              _employeeInfo?.fullName ?? '-',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _employeeInfo?.qualification ?? 'المؤهل غير محدد',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderInfoItem(Icons.business, 'القسم',
                    _employeeInfo?.departmentName ?? '-'),
                _buildHeaderInfoItem(
                    Icons.work, 'المنصب', _employeeInfo?.positionName ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 24),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12, fontFamily: 'Tajawal')),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Tajawal')),
      ],
    );
  }

  Widget _buildCurrentShiftCard(ShiftData shift) {
    final bool isAssignmentActive = shift.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.access_time_filled,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'الوردية الحالية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isAssignmentActive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isAssignmentActive ? Colors.green : Colors.red,
                        width: 0.5),
                  ),
                  child: Text(
                    isAssignmentActive ? 'نشطة' : 'منتهية',
                    style: TextStyle(
                      color: isAssignmentActive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildShiftDetailRow(
                    'اسم الوردية', shift.shiftName, Icons.label_outline),
                _buildShiftDetailRow(
                    'وقت الوردية اليومي',
                    shift.timeRange ??
                        '${shift.startTimeLabel} - ${shift.endTimeLabel}',
                    Icons.schedule),
                _buildShiftDetailRow(
                    'تاريخ بداية التعيين',
                    shift.assignmentStartDate ?? '-',
                    Icons.calendar_today_outlined),
                _buildShiftDetailRow(
                    'تاريخ نهاية التعيين',
                    shift.assignmentEndDate ?? 'مستمر',
                    Icons.event_busy_outlined),
                _buildShiftDetailRow('مدة التعيين',
                    shift.assignmentDuration ?? '-', Icons.history),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildShiftFeatureChip(
                        'نظام مرن', shift.isFlexible, Icons.swap_horiz),
                    const SizedBox(width: 10),
                    _buildShiftFeatureChip('وردية ليلية', shift.isNightShift,
                        Icons.nightlight_round),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'فترة السماح: ${shift.graceInMinutes} دقيقة',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'Tajawal')),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Tajawal',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftFeatureChip(String label, bool isEnabled, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              isEnabled ? AppColors.primary.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.2)
                : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: isEnabled ? AppColors.primary : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled ? AppColors.primary : Colors.grey,
                fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              isEnabled ? Icons.check_circle : Icons.cancel,
              size: 14,
              color: isEnabled ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysCard(ShiftData shift) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'أيام العمل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shift.workDays.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 0, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final day = shift.workDays[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            day.isWorkDay ? Colors.blue[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          day.dayName.substring(0, 1),
                          style: TextStyle(
                            color:
                                day.isWorkDay ? AppColors.primary : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      day.dayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            day.isWorkDay ? FontWeight.bold : FontWeight.normal,
                        color: day.isWorkDay ? Colors.black87 : Colors.grey,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const Spacer(),
                    if (!day.isWorkDay)
                      const Text(
                        'إجازة',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal'),
                      )
                    else
                      Text(
                        day.displayRange,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                          fontFamily: 'Tajawal',
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

  Widget _buildEmptyShiftCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30.0),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 50, color: Colors.grey),
            SizedBox(height: 15),
            Text(
              'لا توجد معلومات وردية مسندة حالياً',
              style: TextStyle(
                  fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
