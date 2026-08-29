import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SecurePermissionConfig {
  static const String permissionSalt = 'HROnline_Approvals_Salt_v2026_XK9';
  static const String approvalPermissionCode = 'APPROVALS_MANAGE_V2';
  static const int signatureLength = 32;
}

class SecureApprovalPermission {
  final bool isApprover;
  final int clientId;
  final int employeeId;
  final String employeeNumber;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String serverNonce;
  final String signature;

  SecureApprovalPermission._({
    required this.isApprover,
    required this.clientId,
    required this.employeeId,
    required this.employeeNumber,
    required this.issuedAt,
    required this.expiresAt,
    required this.serverNonce,
    required this.signature,
  });

  bool get isValid {
    final now = DateTime.now();
    if (now.isAfter(expiresAt) || now.isBefore(issuedAt)) return false;
    if (clientId <= 0 || employeeId <= 0) return false;
    if (employeeNumber.trim().isEmpty) return false;
    if (signature.length != _SecurePermissionConfig.signatureLength * 2) {
      return false;
    }
    return true;
  }

  factory SecureApprovalPermission.denied({
    required int clientId,
    required int employeeId,
    required String employeeNumber,
    String? explicitNonce,
  }) {
    final nonce = explicitNonce ?? _generateCryptoNonce(16);
    final issued = DateTime.now();
    final expires = issued.add(const Duration(hours: 8));
    final signature = _computeSignature(
      isApprover: false,
      clientId: clientId,
      employeeId: employeeId,
      employeeNumber: employeeNumber,
      issuedAt: issued,
      expiresAt: expires,
      serverNonce: nonce,
    );
    return SecureApprovalPermission._(
      isApprover: false,
      clientId: clientId,
      employeeId: employeeId,
      employeeNumber: employeeNumber,
      issuedAt: issued,
      expiresAt: expires,
      serverNonce: nonce,
      signature: signature,
    );
  }

  factory SecureApprovalPermission.granted({
    required int clientId,
    required int employeeId,
    required String employeeNumber,
    String? explicitNonce,
  }) {
    final nonce = explicitNonce ?? _generateCryptoNonce(16);
    final issued = DateTime.now();
    final expires = issued.add(const Duration(hours: 8));
    final signature = _computeSignature(
      isApprover: true,
      clientId: clientId,
      employeeId: employeeId,
      employeeNumber: employeeNumber,
      issuedAt: issued,
      expiresAt: expires,
      serverNonce: nonce,
    );
    return SecureApprovalPermission._(
      isApprover: true,
      clientId: clientId,
      employeeId: employeeId,
      employeeNumber: employeeNumber,
      issuedAt: issued,
      expiresAt: expires,
      serverNonce: nonce,
      signature: signature,
    );
  }

  bool verifySignatureIntegrity() {
    final expected = _computeSignature(
      isApprover: isApprover,
      clientId: clientId,
      employeeId: employeeId,
      employeeNumber: employeeNumber,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      serverNonce: serverNonce,
    );
    return expected == signature;
  }

  static String _computeSignature({
    required bool isApprover,
    required int clientId,
    required int employeeId,
    required String employeeNumber,
    required DateTime issuedAt,
    required DateTime expiresAt,
    required String serverNonce,
  }) {
    final payload = StringBuffer();
    payload.write(_SecurePermissionConfig.permissionSalt);
    payload.write('|');
    payload.write(isApprover ? '1' : '0');
    payload.write('|');
    payload.write(_SecurePermissionConfig.approvalPermissionCode);
    payload.write('|');
    payload.write(clientId.toString());
    payload.write('|');
    payload.write(employeeId.toString());
    payload.write('|');
    payload.write(employeeNumber);
    payload.write('|');
    payload.write(issuedAt.microsecondsSinceEpoch.toString());
    payload.write('|');
    payload.write(expiresAt.microsecondsSinceEpoch.toString());
    payload.write('|');
    payload.write(serverNonce);
    payload.write('|');
    payload.write(_SecurePermissionConfig.permissionSalt);

    final bytes = utf8.encode(payload.toString());
    final hash = sha256.convert(bytes);
    final full = hash.toString();
    return full.substring(0, _SecurePermissionConfig.signatureLength * 2);
  }

  String toSecureJson() {
    final map = <String, dynamic>{
      'a': isApprover ? 1 : 0,
      'c': clientId,
      'e': employeeId,
      'n': employeeNumber,
      'i': issuedAt.microsecondsSinceEpoch,
      'x': expiresAt.microsecondsSinceEpoch,
      's': serverNonce,
      'h': signature,
    };
    final raw = jsonEncode(map);
    final bytes = utf8.encode(raw);
    return base64Url.encode(bytes);
  }

  factory SecureApprovalPermission.fromSecureJson(String token) {
    try {
      if (token.trim().isEmpty) {
        throw const FormatException('Empty token');
      }
      final bytes = base64Url.decode(token.trim());
      final raw = utf8.decode(bytes);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final isApprover = (map['a'] ?? 0) == 1;
      final clientId = (map['c'] ?? 0) as int;
      final employeeId = (map['e'] ?? 0) as int;
      final employeeNumber = (map['n'] ?? '') as String;
      final issuedAt = DateTime.fromMicrosecondsSinceEpoch(
          (map['i'] ?? 0) as int,
          isUtc: false);
      final expiresAt = DateTime.fromMicrosecondsSinceEpoch(
          (map['x'] ?? 0) as int,
          isUtc: false);
      final serverNonce = (map['s'] ?? '') as String;
      final signature = (map['h'] ?? '') as String;

      final perm = SecureApprovalPermission._(
        isApprover: isApprover,
        clientId: clientId,
        employeeId: employeeId,
        employeeNumber: employeeNumber,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        serverNonce: serverNonce,
        signature: signature,
      );
      if (!perm.verifySignatureIntegrity()) {
        throw const FormatException('Signature tampered');
      }
      return perm;
    } catch (e) {
      return SecureApprovalPermission.denied(
        clientId: 0,
        employeeId: 0,
        employeeNumber: '',
      );
    }
  }

  bool canApproveForContext({
    required int targetClientId,
    required int? targetEmployeeId,
    String? targetEmployeeNumber,
  }) {
    if (!isValid || !isApprover) return false;
    if (!verifySignatureIntegrity()) return false;
    if (clientId != targetClientId) return false;
    if (targetEmployeeId != null && employeeId <= 0) return false;
    if (targetEmployeeNumber != null &&
        targetEmployeeNumber.isNotEmpty &&
        employeeNumber.isEmpty) return false;
    return true;
  }
}

class ApprovalPermissionService {
  static SecureApprovalPermission? _cachedPermission;
  static const String _storageKey = 'secure_approval_permission_v2026';

  static SecureApprovalPermission evaluateApproverFromSignals({
    required int clientId,
    required int employeeId,
    required String employeeNumber,
    required String rulesRaw,
    required bool? serverApprovalAccess,
    required List<dynamic>? pendingApprovalItems,
  }) {
    var isApprover = false;

    final rules = rulesRaw.toLowerCase().trim();
    if (rules.isNotEmpty) {
      const ruleKeywords = [
        'approver',
        'approval_admin',
        'approvals',
        'approval_manager',
        'workflow_approver',
        'hr_manager',
        'hr_admin',
        'system_admin',
        'admin',
      ];
      for (final kw in ruleKeywords) {
        if (rules.contains(kw)) {
          isApprover = true;
          break;
        }
      }
    }

    if (serverApprovalAccess == true) isApprover = true;
    if (serverApprovalAccess is String &&
        (serverApprovalAccess as String).toLowerCase() == 'true') {
      isApprover = true;
    }

    if (pendingApprovalItems != null && pendingApprovalItems.isNotEmpty) {
      isApprover = true;
    }

    if (isApprover) {
      return SecureApprovalPermission.granted(
        clientId: clientId,
        employeeId: employeeId,
        employeeNumber: employeeNumber,
      );
    } else {
      return SecureApprovalPermission.denied(
        clientId: clientId,
        employeeId: employeeId,
        employeeNumber: employeeNumber,
      );
    }
  }

  static SecureApprovalPermission get currentCached =>
      _cachedPermission ??
      SecureApprovalPermission.denied(
        clientId: 0,
        employeeId: 0,
        employeeNumber: '',
      );

  static void updateCached(SecureApprovalPermission perm) {
    _cachedPermission = perm;
  }

  static void invalidateCache() {
    _cachedPermission = null;
  }

  static Future<void> persistSecurely(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, token);
    } catch (_) {}
  }

  static Future<String?> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_storageKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    invalidateCache();
  }
}

String _generateCryptoNonce(int lengthBytes) {
  final rng = Random.secure();
  final bytes = Uint8List(lengthBytes);
  for (int i = 0; i < lengthBytes; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return base64Url.encode(bytes);
}
