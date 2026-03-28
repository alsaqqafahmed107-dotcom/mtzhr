import 'lib/config/api_config.dart';

void main() async {
  print('🚀 بدء التطبيق...');
  
  print('🔗 الرابط قبل التهيئة: "${ApiConfig.baseUrl}"');
  
  print('🔧 تهيئة ApiConfig...');
  await ApiConfig.initialize();
  
  print('✅ الرابط بعد التهيئة: "${ApiConfig.baseUrl}"');
  print('✅ loginUrl: ${ApiConfig.loginUrl}');
  
  print('�� التطبيق جاهز!');
} 