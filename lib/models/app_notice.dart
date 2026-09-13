class AppNotice {
  final int noticeId;
  final String noticeType;
  final String titleAr;
  final String messageAr;
  final String buttonTextAr;
  final String titleEn;
  final String messageEn;
  final String buttonTextEn;
  final String buttonUrl;
  final bool showOnLogin;
  final bool showOnHome;
  final int displayOrder;

  const AppNotice({
    required this.noticeId,
    required this.noticeType,
    required this.titleAr,
    required this.messageAr,
    required this.buttonTextAr,
    required this.titleEn,
    required this.messageEn,
    required this.buttonTextEn,
    required this.buttonUrl,
    required this.showOnLogin,
    required this.showOnHome,
    required this.displayOrder,
  });

  String titleFor(String lang) => lang == 'ar' ? titleAr : titleEn;
  String messageFor(String lang) => lang == 'ar' ? messageAr : messageEn;
  String buttonTextFor(String lang) => lang == 'ar' ? buttonTextAr : buttonTextEn;

  bool get hasAction => buttonUrl.trim().isNotEmpty;

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes' || s == 'y';
    }

    return AppNotice(
      noticeId: toInt(json['NoticeId'] ?? json['noticeId'], 0),
      noticeType: (json['NoticeType'] ?? json['noticeType'] ?? 'info').toString(),
      titleAr: (json['TitleAr'] ?? json['titleAr'] ?? '').toString(),
      messageAr: (json['MessageAr'] ?? json['messageAr'] ?? '').toString(),
      buttonTextAr: (json['ButtonTextAr'] ?? json['buttonTextAr'] ?? '').toString(),
      titleEn: (json['TitleEn'] ?? json['titleEn'] ?? '').toString(),
      messageEn: (json['MessageEn'] ?? json['messageEn'] ?? '').toString(),
      buttonTextEn: (json['ButtonTextEn'] ?? json['buttonTextEn'] ?? '').toString(),
      buttonUrl: (json['ButtonUrl'] ?? json['buttonUrl'] ?? '').toString(),
      showOnLogin: toBool(json['ShowOnLogin'] ?? json['showOnLogin']),
      showOnHome: toBool(json['ShowOnHome'] ?? json['showOnHome']),
      displayOrder: toInt(json['DisplayOrder'] ?? json['displayOrder'], 0),
    );
  }
}

