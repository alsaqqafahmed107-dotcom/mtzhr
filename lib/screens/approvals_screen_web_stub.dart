import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/request.dart' as request_models;
import '../models/api_models.dart' as api_models;
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class ApprovalsScreen extends StatefulWidget {
  final String employeeId;
  final api_models.EmployeeData employeeData;

  const ApprovalsScreen({
    super.key,
    required this.employeeId,
    required this.employeeData,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  bool _loading = true;
  String? _error;
  List<request_models.EmployeeRequest> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getPendingRequestsForApproval(
        widget.employeeData.clientID,
        approverId: widget.employeeData.employeeID,
      );
      if (resp['Success'] == true) {
        final data = (resp['Data'] as List? ?? [])
            .map((e) => _parseRequest(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _items = data;
          _loading = false;
        });
      } else {
        setState(() {
          _error = resp['Message']?.toString() ?? 'Load error';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  request_models.EmployeeRequest _parseRequest(Map<String, dynamic> json) {
    final statusStr = (json['Status'] ?? 'pending').toString().toLowerCase();
    request_models.RequestStatus status;
    switch (statusStr) {
      case 'approved':
        status = request_models.RequestStatus.approved;
        break;
      case 'rejected':
        status = request_models.RequestStatus.rejected;
        break;
      case 'cancelled':
        status = request_models.RequestStatus.cancelled;
        break;
      default:
        status = request_models.RequestStatus.pending;
    }
    DateTime _try(String? s) {
      try {
        if (s != null && s.isNotEmpty) return DateTime.parse(s);
      } catch (_) {}
      return DateTime.now();
    }
    return request_models.EmployeeRequest(
      id: json['RequestID']?.toString() ?? json['ID']?.toString() ?? '',
      requestNumber: json['RequestNumber']?.toString() ?? '',
      employeeId: json['EmployeeID']?.toString() ?? '',
      employeeName: json['EmployeeName']?.toString() ?? '',
      type: _parseType(json['RequestTypeName']?.toString()),
      title: json['RequestTypeName']?.toString() ?? '',
      description: json['Description']?.toString() ?? '',
      startDate: _try(json['StartDate']?.toString()),
      endDate: _try(json['EndDate']?.toString()),
      status: status,
      priority: json['Priority']?.toString() ?? 'Normal',
      createdAt: _try(json['CreatedDate']?.toString()),
      approvedBy: null,
      rejectionReason: null,
      employeeNumber: json['EmployeeNumber']?.toString() ?? '',
    );
  }

  request_models.RequestType _parseType(String? name) {
    if (name == null) return request_models.RequestType.other;
    final n = name.toLowerCase();
    if (n.contains('loan') || n.contains('سلفة')) {
      return request_models.RequestType.loan;
    }
    if (n.contains('leave') || n.contains('إجازة')) {
      return request_models.RequestType.leave;
    }
    return request_models.RequestType.other;
  }

  Future<void> _approveOrReject(
      request_models.EmployeeRequest req, bool approve) async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve
            ? Translations.getText('confirm_approval', lang)
            : Translations.getText('confirm_rejection', lang)),
        content: Text(approve
            ? Translations.getText('confirm_approval_msg', lang)
            : Translations.getText('confirm_rejection_msg', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.getText('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve
                ? Translations.getText('approve', lang)
                : Translations.getText('reject', lang)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(SnackBar(
      content: Text(Translations.getText('processing', lang)),
    ));
    final res = await ApiService.approveRequest(
      widget.employeeData.clientID,
      requestId: req.id,
      approverId: widget.employeeData.employeeID,
      approved: approve,
    );
    scaffold.hideCurrentSnackBar();
    if (res['Success'] == true) {
      scaffold.showSnackBar(SnackBar(
        content: Text(approve
            ? Translations.getText('approved_successfully', lang)
            : Translations.getText('rejected_successfully', lang)),
      ));
      _load();
    } else {
      scaffold.showSnackBar(SnackBar(
        content: Text(res['Message']?.toString() ??
            Translations.getText('error_generic', lang)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('approvals', lang)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error, size: 32),
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(Translations.getText('retry', lang)),
                      )
                    ],
                  ),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                Translations.getText('no_pending_requests', lang),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final r = _items[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r.title,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            r.requestNumber,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      r.description.isEmpty
                                          ? Translations.getText(
                                              'no_description', lang)
                                          : r.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _approveOrReject(r, false),
                                            icon: const Icon(Icons.close),
                                            label: Text(Translations.getText(
                                                'reject', lang)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () =>
                                                _approveOrReject(r, true),
                                            icon: const Icon(Icons.check),
                                            label: Text(Translations.getText(
                                                'approve', lang)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

