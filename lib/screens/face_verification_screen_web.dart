import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class FaceVerificationScreen extends StatelessWidget {
  final String employeeNumber;
  final int clientId;
  final bool showResetButton;

  const FaceVerificationScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
    this.showResetButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>().currentLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('face_verification', lang)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Translations.getText('feature_not_available_web', lang),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
