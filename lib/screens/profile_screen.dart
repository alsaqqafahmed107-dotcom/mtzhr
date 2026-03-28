import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import 'login_screen.dart';
import 'employee_full_info_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Employee employee;
  final int clientId;

  const ProfileScreen({
    super.key,
    required this.employee,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isRTL = languageService.isArabic;
    final lang = languageService.isArabic ? 'ar' : 'en';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(Translations.getText('profile', lang)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Header
              _buildProfileHeader(context),
              const SizedBox(height: 24),

              // Profile Details
              _buildProfileDetails(context),
              const SizedBox(height: 24),

              // Actions
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
            child: Icon(
              Icons.person,
              size: 35,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.position,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                if (employee.department.isNotEmpty)
                  Text(
                    employee.department,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails(BuildContext context) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.isArabic ? 'ar' : 'en';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.getText('personal_information', lang),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailRow(Translations.getText('employee_number', lang),
              employee.employeeNumber, Icons.badge),
          _buildDetailRow(
              Translations.getText('email', lang), employee.email, Icons.email),
          _buildDetailRow(Translations.getText('phone_number', lang),
              employee.phone, Icons.phone),
          _buildDetailRow(
              Translations.getText('hire_date', lang),
              employee.hireDate.toString().substring(0, 10),
              Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.isArabic ? 'ar' : 'en';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.getText('settings', lang),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionTile(
            Translations.getText('user_information', lang),
            Icons.person,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeFullInfoScreen(
                    clientId: clientId,
                    email: employee.email,
                  ),
                ),
              );
            },
          ),
          _buildActionTile(
            Translations.getText('change_password', lang),
            Icons.lock,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePasswordScreen(
                    email: employee.email,
                    clientId: clientId,
                  ),
                ),
              );
            },
          ),
          _buildActionTile(
            Translations.getText('logout', lang),
            Icons.logout,
            () {
              _handleLogout(context);
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.1)
              : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF0EA5E9),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _handleLogout(BuildContext context) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.isArabic ? 'ar' : 'en';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.getText('logout_confirmation', lang)),
        content: Text(Translations.getText('logout_confirm_message', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Translations.getText('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // مسح الجلسة والتوجيه إلى صفحة تسجيل الدخول
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_data');
              await prefs.setBool('is_logged_in', false);
              
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(Translations.getText('logout', lang)),
          ),
        ],
      ),
    );
  }
}
