import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import '../services/password_reset_api.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = Translations.getText('enter_verification_code', _getLang()));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await PasswordResetApi.verifyOtp(widget.email, otp);
      if (response['success'] == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(email: widget.email, otp: otp),
            ),
          );
        }
      } else {
        setState(() => _errorMessage = response['message'] ?? 'Invalid OTP');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendOTP() async {
    setState(() => _isLoading = true);
    try {
      final response = await PasswordResetApi.requestOtp(widget.email);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.getText('otp_sent_success', _getLang()))),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getLang() {
    return Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final lang = _getLang();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(Translations.getText('verification_code', lang)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mark_email_read_outlined, size: 64, color: scheme.primary),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              Translations.getText('verification_code', lang),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${Translations.getText('otp_sent_success', lang)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              widget.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 4,
              shadowColor: scheme.shadow.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: InputDecoration(
                        labelText: Translations.getText('verification_code', lang),
                        hintText: '000000',
                        counterText: '',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 16, color: scheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!, style: TextStyle(color: scheme.error, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _handleResendOTP,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: Text(Translations.getText('send_otp', lang)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleVerifyOTP,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(Translations.getText('verify_and_continue', lang),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
