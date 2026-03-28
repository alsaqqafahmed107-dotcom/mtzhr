import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/salary_details.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class SalaryDetailsScreen extends StatefulWidget {
  final int? employeeId;
  final int? clientId;

  const SalaryDetailsScreen({super.key, this.employeeId, this.clientId});

  @override
  State<SalaryDetailsScreen> createState() => _SalaryDetailsScreenState();
}

class _SalaryDetailsScreenState extends State<SalaryDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  SalaryDetailsModel? _salaryDetails;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      int? empId = widget.employeeId;
      int? cId = widget.clientId;

      // محاولة جلب البيانات من SharedPreferences إذا لم تكن ممررة
      if (empId == null || cId == null) {
        final prefs = await SharedPreferences.getInstance();
        // جلب المعرفات المحفوظة عند تسجيل الدخول
        empId ??= prefs.getInt('employeeID');
        cId ??= prefs.getInt('clientID');
      }

      if (empId == null || cId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'بيانات الموظف غير متوفرة';
        });
        return;
      }

      final result = await ApiService.getSalaryDetails(
        cId,
        empId,
        _selectedMonth,
        _selectedYear,
      );

      if (result['success']) {
        setState(() {
          _salaryDetails = SalaryDetailsModel.fromJson(result['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('salary_details_title', lang)),
        elevation: 0,
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthYearPicker(lang),
          Expanded(
            child: _buildContent(lang, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearPicker(String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0EA5E9),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPicker(
              label: Translations.getText('month', lang),
              value: _selectedMonth,
              items: List.generate(12, (index) {
                final monthKeys = [
                  'january', 'february', 'march', 'april', 'may', 'june',
                  'july', 'august', 'september', 'october', 'november', 'december'
                ];
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(Translations.getText(monthKeys[index], lang)),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _fetchData();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildPicker(
              label: Translations.getText('year', lang),
              value: _selectedYear,
              items: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _fetchData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required String label,
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: const Color(0xFF0EA5E9),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(String lang, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                ),
                child: Text(Translations.getText('retry', lang)),
              ),
            ],
          ),
        ),
      );
    }

    if (_salaryDetails == null || (_salaryDetails!.additions.isEmpty && _salaryDetails!.deductions.isEmpty && _salaryDetails!.basicSalary == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payments_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              Translations.getText('no_data', lang),
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(lang, theme),
          const SizedBox(height: 24),
          // الراتب الأساسي كبداية
          _buildInfoItem(
            Translations.getText('basic_salary', lang),
            _salaryDetails!.basicSalary,
            Colors.blueGrey,
            Icons.account_balance_wallet,
            lang,
          ),
          const Divider(height: 32),
          _buildItemsSection(
            title: Translations.getText('allowances', lang),
            items: _salaryDetails!.additions,
            isAddition: true,
            lang: lang,
          ),
          const SizedBox(height: 20),
          _buildItemsSection(
            title: Translations.getText('deductions', lang),
            items: _salaryDetails!.deductions,
            isAddition: false,
            lang: lang,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String lang, ThemeData theme) {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFF0EA5E9).withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              Translations.getText('net_salary', lang),
              style: const TextStyle(
                color: Colors.white, // Changed from white70
                fontSize: 18, // Increased size
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_salaryDetails!.netSalary.toStringAsFixed(2)} ${Translations.getText('currency_sar', lang)}',
              style: const TextStyle(
                color: Colors.white, // Keep white but make it pop
                fontSize: 42, // Increased size from 36
                fontWeight: FontWeight.w900, // Thicker weight
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  Translations.getText('total_additions', lang),
                  _salaryDetails!.totalAdditions,
                  const Color(0xFF22C55E), // More vibrant Emerald Green
                  lang,
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildSummaryItem(
                  Translations.getText('total_deductions', lang),
                  _salaryDetails!.totalDeductions,
                  const Color(0xFFFF3B3B), // Brighter Vivid Red
                  lang,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, String lang) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white, // Clear white instead of greyish
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${amount.toStringAsFixed(2)} ${Translations.getText('currency_sar', lang)}',
          style: TextStyle(
            color: color,
            fontSize: 20, // Increased for clarity
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, double amount, Color color, IconData icon, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ${Translations.getText('currency_sar', lang)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection({
    required String title,
    required List<SalaryItemModel> items,
    required bool isAddition,
    required String lang,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: isAddition ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          color: themeData.brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(
                  lang == 'ar' ? item.nameAr : item.nameEn,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  '${isAddition ? '+' : '-'}${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAddition ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  ThemeData get themeData => Theme.of(context);
}
