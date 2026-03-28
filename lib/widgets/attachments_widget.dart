import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../services/permission_service.dart';
import 'package:flutter/services.dart';
import '../utils/file_actions.dart';
import 'package:open_file/open_file.dart';

class AttachmentsWidget extends StatelessWidget {
  final List<dynamic> attachments;
  final int requestId;
  final int clientId;

  const AttachmentsWidget({
    super.key,
    required this.attachments,
    required this.requestId,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildAttachmentsList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.attach_file, color: Colors.blue, size: 20),
        const SizedBox(width: 8),
        Text(
          'المرفقات (${attachments.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: Colors.grey[400], size: 24),
          const SizedBox(width: 12),
          Text(
            'لا توجد مرفقات لهذا الطلب',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        return _buildAttachmentTile(attachment, context);
      },
    );
  }

  Widget _buildAttachmentTile(
      Map<String, dynamic> attachment, BuildContext context) {
    final fileName = attachment['FileName'] ?? 'ملف غير محدد';
    final fileType = (attachment['FileType'] ?? '').toString().toLowerCase();
    final fileSize = attachment['FormattedFileSize'] ?? '';
    final createdDate = attachment['CreatedDate'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: _buildFileIcon(fileType),
        title: Text(
          fileName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'الحجم: $fileSize',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              'تاريخ الرفع: $createdDate',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: _buildActionButtons(attachment, context),
      ),
    );
  }

  Widget _buildFileIcon(String fileType) {
    IconData iconData;
    Color iconColor;

    if (fileType.contains('pdf')) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (fileType.contains('image')) {
      iconData = Icons.image;
      iconColor = Colors.green;
    } else if (fileType.contains('word') || fileType.contains('doc')) {
      iconData = Icons.description;
      iconColor = Colors.blue;
    } else if (fileType.contains('excel') || fileType.contains('xls')) {
      iconData = Icons.table_chart;
      iconColor = Colors.green;
    } else if (fileType.contains('audio')) {
      iconData = Icons.audiotrack;
      iconColor = Colors.orange;
    } else if (fileType.contains('video')) {
      iconData = Icons.videocam;
      iconColor = Colors.purple;
    } else {
      iconData = Icons.attach_file;
      iconColor = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Widget _buildActionButtons(
      Map<String, dynamic> attachment, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر فتح المرفق
        IconButton(
          icon: const Icon(Icons.visibility, color: Colors.green, size: 20),
          tooltip: 'فتح المرفق',
          onPressed: () => _openAttachment(attachment, context),
        ),
        // زر تحميل المرفق
        IconButton(
          icon: const Icon(Icons.download, color: Colors.blue, size: 20),
          tooltip: 'تحميل المرفق',
          onPressed: () => _downloadAttachment(attachment, context),
        ),
      ],
    );
  }

  Future<void> _openAttachment(
      Map<String, dynamic> attachment, BuildContext context) async {
    try {
      final fileName = attachment['FileName'] as String? ?? 'ملف غير محدد';
      final attachmentId = attachment['ID'] as int? ?? 0;

      // إظهار مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('جاري فتح: $fileName'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      // طلب أذونات الملفات
      final hasPermission =
          await PermissionService.requestAllPermissions(context);
      if (!hasPermission) {
        PermissionService.showPermissionError(
          context,
          'يجب منح أذونات الملفات لفتح المرفقات',
        );
        return;
      }

      // تحميل الملف أولاً
      final response = await _downloadFileToTemp(attachmentId, fileName);

      if (response['Success'] == true) {
        final filePath = response['FilePath'] as String;

        // محاولة فتح الملف المحلي بطريقة آمنة
        final opened = await _openFileSafely(filePath, fileName);

        if (opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم فتح: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // إذا لم يمكن فتح الملف المحلي، جرب فتح الرابط المباشر
          final url =
              '${ApiConfig.baseUrl}/api/$clientId/approvals/$requestId/attachments/$attachmentId/download';

          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } else {
            throw Exception('لا يمكن فتح المرفق');
          }
        }
      } else {
        throw Exception('فشل في تحميل المرفق: ${response['Message']}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح المرفق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة مساعدة لتحميل الملف إلى مجلد مؤقت
  Future<Map<String, dynamic>> _downloadFileToTemp(
      int attachmentId, String fileName) async {
    try {
      // جلب الملف من API
      final response = await _downloadAttachmentFromAPI(attachmentId);

      if (response['Success'] == true) {
        if (kIsWeb) {
          return {
            'Success': false,
            'Message': 'هذه الميزة غير متاحة على الويب',
          };
        }

        // حفظ الملف في مجلد مؤقت
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        await writeBytesToFile(
          filePath,
          Uint8List.fromList((response['Data'] as List).cast<int>()),
        );

        return {
          'Success': true,
          'FilePath': filePath,
          'Message': 'تم تحميل الملف بنجاح',
        };
      } else {
        return response;
      }
    } catch (e) {
      return {
        'Success': false,
        'Message': 'خطأ في تحميل الملف: $e',
      };
    }
  }

  // دالة مساعدة لجلب المرفق من API
  Future<Map<String, dynamic>> _downloadAttachmentFromAPI(
      int attachmentId) async {
    try {
      final url =
          '${ApiConfig.baseUrl}/api/$clientId/approvals/$requestId/attachments/$attachmentId/download';

      final response = await _makeHttpRequest(url);

      if (response['Success'] == true) {
        return {
          'Success': true,
          'Data': response['Data'],
          'Message': 'تم جلب المرفق بنجاح',
        };
      } else {
        return response;
      }
    } catch (e) {
      return {
        'Success': false,
        'Message': 'خطأ في جلب المرفق: $e',
      };
    }
  }

  // دالة مساعدة لإجراء طلب HTTP
  Future<Map<String, dynamic>> _makeHttpRequest(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/octet-stream',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return {
          'Success': true,
          'Data': response.bodyBytes,
          'Message': 'تم جلب البيانات بنجاح',
        };
      } else {
        return {
          'Success': false,
          'Message': 'فشل في جلب البيانات: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'Success': false,
        'Message': 'خطأ في الاتصال: $e',
      };
    }
  }

  Future<void> _downloadAttachment(
      Map<String, dynamic> attachment, BuildContext context) async {
    try {
      final fileName = attachment['FileName'] as String? ?? 'ملف غير محدد';
      final attachmentId = attachment['ID'] as int? ?? 0;

      print('🔍 بدء تحميل المرفق: $fileName (ID: $attachmentId)');

      // طلب أذونات الملفات
      final hasPermission =
          await PermissionService.requestAllPermissions(context);
      if (!hasPermission) {
        print('❌ لم يتم منح أذونات الملفات');
        PermissionService.showPermissionError(
          context,
          'يجب منح أذونات الملفات لتحميل المرفقات',
        );
        return;
      }

      print('✅ تم منح أذونات الملفات');

      // إظهار مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('جاري تحميل: $fileName'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );

      // تحميل الملف إلى مجلد التحميلات
      final response = await _downloadFileToDownloads(attachmentId, fileName);

      if (response['Success'] == true) {
        final filePath = response['FilePath'] as String;
        final fileSize = response['FileSize'] as int? ?? 0;

        print('✅ تم تحميل الملف بنجاح');
        print('📄 مسار الملف: $filePath');
        print('📊 حجم الملف: $fileSize بايت');

        // إظهار رسالة نجاح مع تفاصيل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تم تحميل: $fileName'),
                Text(
                  'المسار: ${filePath.split('/').last}',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'الحجم: ${_formatFileSize(fileSize)}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );

        // فتح الملف مباشرة بعد التحميل الناجح
        try {
          print('🚀 محاولة فتح الملف مباشرة: $filePath');

          final opened = await _openFileSafely(filePath, fileName);

          if (opened) {
            print('✅ تم فتح الملف بنجاح');

            // إظهار رسالة نجاح إضافية
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم فتح الملف: $fileName'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            print('❌ لا يمكن فتح الملف مباشرة، محاولة فتح مجلد التحميلات');

            // إذا لم يمكن فتح الملف مباشرة، فتح مجلد التحميلات
            final downloadsDir = await getExternalStorageDirectory();
            if (downloadsDir != null) {
              print('📁 محاولة فتح مجلد التحميلات: ${downloadsDir.path}');

              // محاولة فتح مجلد التحميلات بطريقة آمنة
              try {
                final folderUri = await _getFileProviderUri(downloadsDir.path);
                if (folderUri != null && await canLaunchUrl(folderUri)) {
                  await launchUrl(
                    folderUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              } catch (folderError) {
                print('❌ خطأ في فتح مجلد التحميلات: $folderError');
              }
            }
          }
        } catch (e) {
          print('❌ خطأ في فتح الملف: $e');

          // في حالة الفشل، محاولة فتح مجلد التحميلات
          try {
            final downloadsDir = await getExternalStorageDirectory();
            if (downloadsDir != null) {
              final folderUri = await _getFileProviderUri(downloadsDir.path);
              if (folderUri != null && await canLaunchUrl(folderUri)) {
                await launchUrl(
                  folderUri,
                  mode: LaunchMode.externalApplication,
                );
              }
            }
          } catch (folderError) {
            print('❌ خطأ في فتح مجلد التحميلات: $folderError');
          }
        }
      } else {
        print('❌ فشل في تحميل المرفق: ${response['Message']}');
        throw Exception('فشل في تحميل المرفق: ${response['Message']}');
      }
    } catch (e) {
      print('💥 خطأ في تحميل المرفق: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل المرفق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة مساعدة لتنسيق حجم الملف
  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 بايت';

    const k = 1024;
    const sizes = ['بايت', 'كيلوبايت', 'ميجابايت', 'جيجابايت'];
    final i = (log(bytes) / log(k)).floor();

    return '${(bytes / pow(k, i)).toStringAsFixed(2)} ${sizes[i]}';
  }

  // دالة مساعدة لتحميل الملف إلى مجلد التحميلات
  Future<Map<String, dynamic>> _downloadFileToDownloads(
      int attachmentId, String fileName) async {
    try {
      print('📥 بدء تحميل الملف: $fileName (ID: $attachmentId)');

      // جلب الملف من API
      final response = await _downloadAttachmentFromAPI(attachmentId);

      if (response['Success'] == true) {
        print('✅ تم جلب الملف من API بنجاح');
        print('📊 حجم الملف: ${(response['Data'] as List<int>).length} بايت');

        // محاولة حفظ الملف في مجلد التحميلات
        Directory? downloadsDir;

        try {
          // محاولة الحصول على مجلد التحميلات
          downloadsDir = await getExternalStorageDirectory();
          
          if (downloadsDir == null) {
            print('❌ فشل في الحصول على مجلد التحميلات');
            return {
              'Success': false,
              'Message': 'فشل في الحصول على مجلد التحميلات',
            };
          }

          print('📁 مجلد التحميلات: ${downloadsDir.path}');

          // التأكد من وجود المجلد
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
            print('📁 تم إنشاء مجلد التحميلات');
          }

          // تنظيف اسم الملف من الأحرف غير المسموحة
          final cleanFileName = _cleanFileName(fileName);
          print('📄 اسم الملف النظيف: $cleanFileName');

          final file = File('${downloadsDir.path}/$cleanFileName');
          print('📄 مسار الملف الكامل: ${file.path}');

          // كتابة الملف
          await file.writeAsBytes(response['Data'] as List<int>);

          // التحقق من وجود الملف
          if (await file.exists()) {
            final fileSize = await file.length();
            print('✅ تم حفظ الملف بنجاح');
            print('📊 حجم الملف المحفوظ: $fileSize بايت');

            return {
              'Success': true,
              'FilePath': file.path,
              'FileSize': fileSize,
              'Message': 'تم تحميل الملف بنجاح إلى: ${file.path}',
            };
          } else {
            print('❌ الملف غير موجود بعد الحفظ');
            return {
              'Success': false,
              'Message': 'فشل في حفظ الملف',
            };
          }
                } catch (e) {
          print('❌ خطأ في حفظ الملف: $e');
          return {
            'Success': false,
            'Message': 'خطأ في حفظ الملف: $e',
          };
        }
      } else {
        print('❌ فشل في جلب الملف من API: ${response['Message']}');
        return response;
      }
    } catch (e) {
      print('💥 خطأ عام في تحميل الملف: $e');
      return {
        'Success': false,
        'Message': 'خطأ في تحميل الملف: $e',
      };
    }
  }

  // دالة مساعدة لتنظيف اسم الملف
  String _cleanFileName(String fileName) {
    // إزالة الأحرف غير المسموحة في أسماء الملفات
    final cleanName = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    // التأكد من أن الاسم لا يبدأ بنقطة
    if (cleanName.startsWith('.')) {
      return 'file$cleanName';
    }

    return cleanName;
  }

  // دالة مساعدة لإنشاء URI آمن باستخدام FileProvider
  Future<Uri?> _getFileProviderUri(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // استخدام FileProvider على Android
        final file = File(filePath);
        if (await file.exists()) {
          // محاولة استخدام مسار الملف المباشر أولاً (للتطبيقات المحلية)
          try {
            final directUri = Uri.file(filePath);
            print('🔗 محاولة استخدام URI مباشر: $directUri');
            return directUri;
          } catch (e) {
            print('❌ فشل في استخدام URI مباشر: $e');
          }

          // إذا فشل، استخدام FileProvider
          try {
            // تحديد نوع المسار بناءً على موقع الملف
            String pathType = 'external_files_path';
            if (filePath.contains('/storage/emulated/0/')) {
              pathType = 'external_storage';
            } else if (filePath.contains('/data/data/')) {
              pathType = 'internal_files';
            } else if (filePath.contains('/cache/')) {
              pathType = 'cache_files';
            }

            final fileName = file.path.split('/').last;
            final uri = Uri.parse(
                'content://com.example.mtzhr.fileprovider/$pathType/$fileName');
            print('🔗 تم إنشاء FileProvider URI: $uri');
            return uri;
          } catch (e) {
            print('❌ فشل في إنشاء FileProvider URI: $e');
          }
        } else {
          print('❌ الملف غير موجود: $filePath');
          return null;
        }
      } else {
        // استخدام مسار الملف المباشر على الأنظمة الأخرى
        return Uri.file(filePath);
      }
    } catch (e) {
      print('❌ خطأ في إنشاء FileProvider URI: $e');
      return null;
    }
    return null;
  }

  // دالة مساعدة لفتح الملف بطريقة آمنة
  Future<bool> _openFileSafely(String filePath, String fileName) async {
    try {
      print('🚀 محاولة فتح الملف بطريقة آمنة: $filePath');

      // الطريقة الأولى: محاولة فتح الملف مباشرة
      try {
        final directUri = Uri.file(filePath);
        if (await canLaunchUrl(directUri)) {
          await launchUrl(
            directUri,
            mode: LaunchMode.externalApplication,
          );
          print('✅ تم فتح الملف بنجاح باستخدام URI مباشر');
          return true;
        }
      } catch (e) {
        print('❌ فشل في فتح الملف باستخدام URI مباشر: $e');
      }

      // الطريقة الثانية: استخدام FileProvider
      try {
        final uri = await _getFileProviderUri(filePath);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          print('✅ تم فتح الملف بنجاح باستخدام FileProvider');
          return true;
        }
      } catch (e) {
        print('❌ فشل في فتح الملف باستخدام FileProvider: $e');
      }

      // الطريقة الثالثة: محاولة فتح الملف باستخدام open_file
      try {
        final file = File(filePath);
        if (await file.exists()) {
          print('📄 محاولة فتح الملف باستخدام open_file');

          final result = await OpenFile.open(filePath);
          if (result.type == ResultType.done) {
            print('✅ تم فتح الملف بنجاح باستخدام open_file');
            return true;
          } else {
            print('❌ فشل في فتح الملف باستخدام open_file: ${result.message}');
          }
        }
      } catch (e) {
        print('❌ فشل في فتح الملف باستخدام open_file: $e');
      }

      print('❌ فشل في فتح الملف بجميع الطرق');
      return false;
    } catch (e) {
      print('❌ خطأ عام في فتح الملف: $e');
      return false;
    }
  }
}

// Widget إضافي لعرض تفاصيل المرفق في نافذة منبثقة
class AttachmentDetailDialog extends StatelessWidget {
  final Map<String, dynamic> attachment;

  const AttachmentDetailDialog({
    super.key,
    required this.attachment,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = attachment['FileName'] ?? 'ملف غير محدد';
    final fileType = attachment['FileType'] ?? '';
    final fileSize = attachment['FormattedFileSize'] ?? '';
    final createdDate = attachment['CreatedDate'] ?? '';
    final fileCategory = attachment['FileCategory'] ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تفاصيل المرفق',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('اسم الملف:', fileName),
            _buildDetailRow('نوع الملف:', fileType),
            _buildDetailRow('فئة الملف:', fileCategory),
            _buildDetailRow('حجم الملف:', fileSize),
            _buildDetailRow('تاريخ الرفع:', createdDate),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.visibility),
                  label: Text('فتح'),
                  onPressed: () {
                    Navigator.of(context).pop('open');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.download),
                  label: Text('تحميل'),
                  onPressed: () {
                    Navigator.of(context).pop('download');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
