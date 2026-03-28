import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الوجه'),
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

