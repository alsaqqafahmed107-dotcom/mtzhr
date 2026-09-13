import 'dart:convert';
import 'dart:typed_data';

class MobileAdvertisement {
  final int advertisementId;
  final String title;
  final String bodyText;
  final String buttonText;
  final String linkUrl;
  final String imageData;
  final String imageMimeType;
  final int durationSeconds;
  final int displayOrder;

  const MobileAdvertisement({
    required this.advertisementId,
    required this.title,
    required this.bodyText,
    required this.buttonText,
    required this.linkUrl,
    required this.imageData,
    required this.imageMimeType,
    required this.durationSeconds,
    required this.displayOrder,
  });

  Uint8List? get imageBytes {
    if (imageData.trim().isEmpty) return null;
    try {
      return base64Decode(imageData);
    } catch (_) {
      return null;
    }
  }

  factory MobileAdvertisement.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return MobileAdvertisement(
      advertisementId: toInt(json['AdvertisementId'] ?? json['advertisementId'], 0),
      title: (json['Title'] ?? json['title'] ?? '').toString(),
      bodyText: (json['BodyText'] ?? json['bodyText'] ?? '').toString(),
      buttonText: (json['ButtonText'] ?? json['buttonText'] ?? '').toString(),
      linkUrl: (json['LinkUrl'] ?? json['linkUrl'] ?? '').toString(),
      imageData: (json['ImageData'] ?? json['imageData'] ?? '').toString(),
      imageMimeType: (json['ImageMimeType'] ?? json['imageMimeType'] ?? '').toString(),
      durationSeconds: toInt(json['DurationSeconds'] ?? json['durationSeconds'], 5),
      displayOrder: toInt(json['DisplayOrder'] ?? json['displayOrder'], 0),
    );
  }
}

