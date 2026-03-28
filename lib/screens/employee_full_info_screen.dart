import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/employee_full_info.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class EmployeeFullInfoScreen extends StatefulWidget {
  final int clientId;
  final String email;

  const EmployeeFullInfoScreen({
    super.key,
    required this.clientId,
    required this.email,
  });

  @override
  State<EmployeeFullInfoScreen> createState() => _EmployeeFullInfoScreenState();
}

class _EmployeeFullInfoScreenState extends State<EmployeeFullInfoScreen> {
  EmployeeFullInfo? employeeInfo;
  bool isLoading = true;
  String? errorMessage;
  List<String> expiryNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadEmployeeInfo();
  }

  Future<void> _loadEmployeeInfo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final apiService = ApiService();
      final response = await apiService.getEmployeeFullInfo(
        widget.clientId,
        widget.email,
      );

      setState(() {
        employeeInfo = response;
        isLoading = false;
      });

      // Check document expiry after data loading
      _checkDocumentExpiry();
    } catch (e) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;

      setState(() {
        errorMessage =
            '${Translations.getText('error_loading_data', lang)}: $e';
        isLoading = false;
      });
    }
  }

  void _checkDocumentExpiry() {
    if (employeeInfo == null) return;

    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    final now = DateTime.now();
    final notifications = <String>[];

    // Check national ID/Iqama expiry
    if (employeeInfo!.nationalIdExpiryDate.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(employeeInfo!.nationalIdExpiryDate);
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
      } catch (e) {
        // تجاهل الأخطاء في تنسيق التاريخ
      }
    }

    // Check passport expiry
    if (employeeInfo!.passportExpiryDate.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(employeeInfo!.passportExpiryDate);
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
      } catch (e) {
        // تجاهل الأخطاء في تنسيق التاريخ
      }
    }

    setState(() {
      expiryNotifications = notifications;
    });

    // Show notifications if any
    if (notifications.isNotEmpty) {
      _showExpiryNotifications(notifications);
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
                    child: Text(
                      notification,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isRTL = languageService.currentDirection == TextDirection.rtl;
    final lang = languageService.currentLocale.languageCode;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            Translations.getText('my_information', lang),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: const Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          actions: [
            if (expiryNotifications.isNotEmpty)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () =>
                        _showExpiryNotifications(expiryNotifications),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        expiryNotifications.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadEmployeeInfo,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildErrorWidget()
                : employeeInfo == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              Translations.getText('no_data', lang),
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      )
                    : _buildEmployeeInfo(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEmployeeInfo,
            child: Text(Translations.getText('retry', lang)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfo() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 24),

          // Document Status Summary
          if (expiryNotifications.isNotEmpty) ...[
            _buildDocumentStatusSummary(),
            const SizedBox(height: 24),
          ],

          // Personal Information
          _buildPersonalInfo(),
          const SizedBox(height: 24),

          // Contact Information
          _buildContactInfo(),
          const SizedBox(height: 24),

          // Identity Information
          _buildIdentityInfo(),
          const SizedBox(height: 24),

          // Employment Information
          _buildEmploymentInfo(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              Icons.person,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employeeInfo!.fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Text(
            '${Translations.getText('employee_number', lang)}: ${employeeInfo!.employeeNumber}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatusSummary() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
          Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                Translations.getText('document_expiry_alerts', lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...expiryNotifications.map((notification) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return _buildInfoSection(
      Translations.getText('personal_information', lang),
      [
        _buildInfoRow(
            Translations.getText('full_name', lang),
            employeeInfo!.fullName.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.fullName,
            Icons.person),
        _buildInfoRow(
            Translations.getText('employee_number', lang),
            employeeInfo!.employeeNumber.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.employeeNumber,
            Icons.badge),
        _buildInfoRow(
            Translations.getText('birth_date', lang),
            employeeInfo!.birthDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.birthDate),
            Icons.cake),
        _buildInfoRow(
            Translations.getText('gender', lang),
            employeeInfo!.gender.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.gender == 'M'
                    ? Translations.getText('male', lang)
                    : Translations.getText('female', lang),
            Icons.wc),
        _buildInfoRow(
            Translations.getText('marital_status', lang),
            employeeInfo!.maritalStatus.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.maritalStatus,
            Icons.favorite),
      ],
    );
  }

  Widget _buildContactInfo() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return _buildInfoSection(
      Translations.getText('contact_information', lang),
      [
        _buildInfoRow(
            Translations.getText('email', lang),
            employeeInfo!.email.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.email,
            Icons.email),
        _buildInfoRow(
            Translations.getText('mobile_number', lang),
            employeeInfo!.mobileNumber.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.mobileNumber,
            Icons.phone),
      ],
    );
  }

  Widget _buildIdentityInfo() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return _buildInfoSection(
      Translations.getText('identity_information', lang),
      [
        _buildInfoRow(
            Translations.getText('national_id', lang),
            employeeInfo!.nationalId.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.nationalId,
            Icons.credit_card),
        _buildExpiryInfoRow(
            Translations.getText('national_id_expiry', lang),
            employeeInfo!.nationalIdExpiryDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.nationalIdExpiryDate),
            Icons.event,
            employeeInfo!.nationalIdExpiryDate),
        _buildInfoRow(
            Translations.getText('passport_number', lang),
            employeeInfo!.passportNumber.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.passportNumber,
            Icons.flight),
        _buildExpiryInfoRow(
            Translations.getText('passport_expiry', lang),
            employeeInfo!.passportExpiryDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.passportExpiryDate),
            Icons.event,
            employeeInfo!.passportExpiryDate),
      ],
    );
  }

  Widget _buildEmploymentInfo() {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    return _buildInfoSection(
      Translations.getText('employment_information', lang),
      [
        _buildInfoRow(
            Translations.getText('hire_date', lang),
            employeeInfo!.hireDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.hireDate),
            Icons.work),
        _buildInfoRow(
            Translations.getText('contract_start_date', lang),
            employeeInfo!.contractStartDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.contractStartDate),
            Icons.assignment),
        _buildInfoRow(
            Translations.getText('contract_end_date', lang),
            employeeInfo!.contractEndDate.isEmpty
                ? Translations.getText('not_specified', lang)
                : employeeInfo!.formatDate(employeeInfo!.contractEndDate),
            Icons.assignment_turned_in),
      ],
    );
  }

  Widget _buildExpiryInfoRow(
      String label, String value, IconData icon, String expiryDate) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    Color statusColor = Colors.green;
    String statusText = '';

    if (expiryDate.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiryDate);
        final now = DateTime.now();
        final daysUntilExpiry = expiry.difference(now).inDays;

        if (daysUntilExpiry < 0) {
          statusColor = Colors.red;
          statusText = Translations.getText('expired', lang);
        } else if (daysUntilExpiry <= 60) {
          statusColor = Colors.orange;
          statusText = Translations.getTextWithParams(
              'expiring_in_days', lang, {'days': daysUntilExpiry.toString()});
        } else {
          statusColor = Colors.green;
          statusText = Translations.getText('valid', lang);
        }
      } catch (e) {
        statusColor = Colors.grey;
        statusText = Translations.getText('unknown', lang);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0EA5E9),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0EA5E9),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
