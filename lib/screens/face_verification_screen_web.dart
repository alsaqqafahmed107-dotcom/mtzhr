import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من الوجه'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'هذه الميزة غير متاحة على الويب',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

