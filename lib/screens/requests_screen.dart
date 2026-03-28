import 'package:flutter/material.dart';
import '../models/request.dart' as request_models;
import '../models/api_models.dart' as api_models;
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import '../services/api_service.dart';
import 'create_request_screen.dart';

class RequestsScreen extends StatefulWidget {
  final String employeeId;
  final api_models.EmployeeData employeeData;

  const RequestsScreen({
    super.key,
    required this.employeeId,
    required this.employeeData,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<request_models.EmployeeRequest> _requests = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // جلب الطلبات من API
      final requests = await _fetchRequestsFromAPI();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'حدث خطأ في تحميل الطلبات: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<request_models.EmployeeRequest>> _fetchRequestsFromAPI() async {
    try {
      // استخدام API لجلب الطلبات
      final response = await ApiService.getRequests(
        widget.employeeData.clientID,
        employeeId: widget.employeeData.employeeID,
      );

      if (response['Success'] == true) {
        final List<dynamic> data = response['Data'] ?? [];
        return data.map((json) => _parseRequestFromAPI(json)).toList();
      } else {
        throw Exception(response['Message'] ?? 'فشل في جلب الطلبات');
      }
    } catch (e) {
      // في حالة فشل API، نرجع قائمة فارغة
      print('فشل في جلب الطلبات من API: $e');
      return [];
    }
  }

  request_models.EmployeeRequest _parseRequestFromAPI(
      Map<String, dynamic> json) {
    // تحويل البيانات من API إلى نموذج EmployeeRequest
    return request_models.EmployeeRequest(
      id: json['ID']?.toString() ?? '',
      requestNumber: json['RequestNumber']?.toString() ?? '',
      employeeId: json['EmployeeID']?.toString() ?? '',
      employeeName: json['EmployeeName']?.toString() ?? '',
      type: _parseRequestType(json['RequestTypeName']),
      title: json['RequestTypeName'] ?? '',
      description: '', // سيتم جلبها من تفاصيل الطلب
      startDate: DateTime.tryParse(json['CreatedDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['CreatedDate'] ?? '') ?? DateTime.now(),
      status: _parseRequestStatus(json['Status']),
      priority: json['Priority']?.toString() ?? 'Normal',
      createdAt: DateTime.tryParse(json['CreatedDate'] ?? '') ?? DateTime.now(),
      approvedBy: null,
      rejectionReason: null,
    );
  }

  request_models.RequestType _parseRequestType(String? typeName) {
    if (typeName?.contains('سلفة') == true) {
      return request_models.RequestType.loan;
    } else if (typeName?.contains('إجازة') == true) {
      return request_models.RequestType.leave;
    }
    return request_models.RequestType.other;
  }

  request_models.RequestStatus _parseRequestStatus(String? status) {
    switch (status?.toLowerCase()) {
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
      case 'ملغي':
        return request_models.RequestStatus.cancelled;
      default:
        return request_models.RequestStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('my_requests', Provider.of<LanguageService>(context).currentLocale.languageCode)),
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateRequestScreen(
                    employeeData: widget.employeeData,
                  ),
                ),
              );

              // إذا تم إنشاء طلب بنجاح، قم بتحديث الشاشة
              if (result == true) {
                _loadRequests();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(Translations.getText('loading', Provider.of<LanguageService>(context).currentLocale.languageCode)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment,
              size: 100,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'اضغط على زر + لإنشاء طلب جديد',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(request_models.EmployeeRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.status) {
      case request_models.RequestStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'معلق';
        statusIcon = Icons.pending;
        break;
      case request_models.RequestStatus.approved:
        statusColor = const Color(0xFF10B981);
        statusText = 'معتمد';
        statusIcon = Icons.check_circle;
        break;
      case request_models.RequestStatus.rejected:
        statusColor = const Color(0xFFEF4444);
        statusText = 'مرفوض';
        statusIcon = Icons.cancel;
        break;
      case request_models.RequestStatus.cancelled:
        statusColor = Colors.grey;
        statusText = 'ملغي';
        statusIcon = Icons.block;
        break;
    }

    // تحديد لون الأولوية
    Color priorityColor;
    String priorityText;
    switch (request.priority.toLowerCase()) {
      case 'high':
      case 'عالية':
        priorityColor = const Color(0xFFEF4444);
        priorityText = 'عالية';
        break;
      case 'medium':
      case 'متوسطة':
        priorityColor = const Color(0xFFF59E0B);
        priorityText = 'متوسطة';
        break;
      case 'low':
      case 'منخفضة':
        priorityColor = const Color(0xFF10B981);
        priorityText = 'منخفضة';
        break;
      default:
        priorityColor = const Color(0xFF6B7280);
        priorityText = 'عادية';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showRequestDetails(request),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف الأول: رقم الطلب ونوع الطلب
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRequestTypeIcon(request.type),
                            size: 16,
                            color: const Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // رقم الطلب
                Row(
                  children: [
                    Icon(
                      Icons.numbers,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'رقم الطلب: ${request.requestNumber}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // اسم الموظف
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.employeeName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // الصف الأخير: التاريخ والأولوية
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(request.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priorityText,
                        style: TextStyle(
                          fontSize: 10,
                          color: priorityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      case request_models.RequestType.other:
        return Icons.assignment;
    }
    return Icons.assignment; // default return
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showRequestDetails(request_models.EmployeeRequest request) async {
    // إظهار مؤشر التحميل أولاً
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // جلب تفاصيل الطلب من API
      final details = await _fetchRequestDetails(request.id);
      Navigator.of(context).pop(); // إغلاق مؤشر التحميل

      // عرض تفاصيل الطلب
      _showRequestDetailsDialog(request, details);
    } catch (e) {
      Navigator.of(context).pop(); // إغلاق مؤشر التحميل
      // عرض تفاصيل الطلب بدون معلومات إضافية
      _showRequestDetailsDialog(request, null);
    }
  }

  Future<Map<String, dynamic>?> _fetchRequestDetails(String requestId) async {
    try {
      final response = await ApiService.getRequestDetails(
        widget.employeeData.clientID,
        int.parse(requestId),
      );

      if (response['Success'] == true) {
        return response['Data'];
      }
      return null;
    } catch (e) {
      print('فشل في جلب تفاصيل الطلب: $e');
      return null;
    }
  }

  void _showRequestDetailsDialog(
      request_models.EmployeeRequest request, Map<String, dynamic>? details) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getRequestTypeIcon(request.type),
                  color: const Color(0xFF0EA5E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      request.requestNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('اسم الموظف:', request.employeeName),
                _buildDetailRow('الحالة:', _getStatusText(request.status)),
                _buildDetailRow(
                    'الأولوية:', _getPriorityText(request.priority)),
                _buildDetailRow(
                    'تاريخ الإنشاء:', _formatDate(request.createdAt)),
                if (details != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'تفاصيل إضافية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // عرض التفاصيل الإضافية حسب نوع الطلب
                  if (details['AdditionalDetails'] != null) ...[
                    _buildAdditionalDetails(details['AdditionalDetails']),
                  ],

                  // عرض الموافقات إذا وجدت
                  if (details['Approvals'] != null &&
                      details['Approvals'].isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'سير الموافقات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildApprovalsList(details['Approvals']),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails(Map<String, dynamic> details) {
    List<Widget> widgets = [];

    details.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        String label = _getDetailLabel(key);
        String displayValue = _formatDetailValue(key, value);
        widgets.add(_buildDetailRow(label, displayValue));
      }
    });

    return Column(children: widgets);
  }

  String _getDetailLabel(String key) {
    switch (key) {
      case 'LoanType':
        return 'نوع السلفة:';
      case 'LoanAmount':
        return 'مبلغ السلفة:';
      case 'MonthlyInstallment':
        return 'القسط الشهري:';
      case 'NumberOfInstallments':
        return 'عدد الأقساط:';
      case 'LoanStartDate':
        return 'تاريخ البداية:';
      case 'LoanEndDate':
        return 'تاريخ النهاية:';
      case 'LoanDescription':
        return 'الوصف:';
      case 'LeaveTypeName':
        return 'نوع الإجازة:';
      case 'LeaveStartDate':
        return 'تاريخ البداية:';
      case 'LeaveEndDate':
        return 'تاريخ النهاية:';
      case 'LeaveDays':
        return 'عدد الأيام:';
      case 'LeaveReason':
        return 'السبب:';
      default:
        return '$key:';
    }
  }

  String _formatDetailValue(String key, dynamic value) {
    if (key.contains('Amount') || key.contains('Installment')) {
      return '${value.toString()} ريال';
    } else if (key.contains('Date')) {
      return value.toString();
    } else if (key.contains('Days') || key.contains('Installments')) {
      return '${value.toString()} يوم';
    }
    return value.toString();
  }

  Widget _buildApprovalsList(List<dynamic> approvals) {
    return Column(
      children: approvals.map<Widget>((approval) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      approval['ApproverName'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getApprovalStatusColor(approval['Status'])
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getApprovalStatusText(approval['Status']),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getApprovalStatusColor(approval['Status']),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (approval['Comments'] != null &&
                  approval['Comments'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'ملاحظات: ${approval['Comments']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (approval['ApprovalDate'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'التاريخ: ${approval['ApprovalDate']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getApprovalStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'معتمد':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'مرفوض':
        return const Color(0xFFEF4444);
      case 'pending':
      case 'معلق':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String _getApprovalStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'معتمد':
        return 'معتمد';
      case 'rejected':
      case 'مرفوض':
        return 'مرفوض';
      case 'pending':
      case 'معلق':
        return 'معلق';
      default:
        return 'غير محدد';
    }
  }

  String _getStatusText(request_models.RequestStatus status) {
    switch (status) {
      case request_models.RequestStatus.pending:
        return 'معلق';
      case request_models.RequestStatus.approved:
        return 'معتمد';
      case request_models.RequestStatus.rejected:
        return 'مرفوض';
      case request_models.RequestStatus.cancelled:
        return 'ملغي';
    }
  }

  String _getPriorityText(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
      case 'عالية':
        return 'عالية';
      case 'medium':
      case 'متوسطة':
        return 'متوسطة';
      case 'low':
      case 'منخفضة':
        return 'منخفضة';
      default:
        return 'عادية';
    }
  }
}
