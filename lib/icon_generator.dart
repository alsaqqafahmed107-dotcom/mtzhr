import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class IconGenerator {
  static Future<void> generateIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(1024, 1024);
    
    // خلفية متدرجة
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0EA5E9), // أزرق
          Color(0xFF8B5CF6), // بنفسجي
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // دائرة بيضاء في المنتصف
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.3,
      circlePaint,
    );
    
    // أيقونة العين الذكية
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // رسم العين
    final eyeCenter = Offset(size.width / 2, size.height / 2);
    final eyeRadius = size.width * 0.15;
    
    // العين الخارجية
    canvas.drawCircle(eyeCenter, eyeRadius, eyePaint);
    
    // العين الداخلية
    final innerEyePaint = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(eyeCenter, eyeRadius * 0.6, innerEyePaint);
    
    // البؤبؤ
    final pupilPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(eyeCenter, eyeRadius * 0.3, pupilPaint);
    
    // النص
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'SV',
        style: TextStyle(
          color: Colors.white,
          fontSize: 200,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height * 0.7,
      ),
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    
    // حفظ الأيقونة
    final file = File('assets/icon/icon.png');
    await file.writeAsBytes(bytes);
    
    print('✅ تم إنشاء الأيقونة بنجاح في assets/icon/icon.png');
  }
} 