import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/translations.dart';

class FaceEnrollmentScreen extends StatelessWidget {
  final String employeeNumber;
  final int clientId;

  const FaceEnrollmentScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>().currentLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.getText('face_enrollment', lang)),
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
