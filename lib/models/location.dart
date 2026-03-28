class LocationModel {
  final int id;
  final String locationName;
  final String? locationAddress;
  final double? longitude;
  final double? latitude;
  final String? locationType;
  final bool isActive;
  final int? radiusMeters;
  final String? timezone;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final String? description;
  final DateTime? createdDate;
  final int? createdBy;
  final DateTime? modifiedDate;
  final int? modifiedBy;

  LocationModel({
    required this.id,
    required this.locationName,
    this.locationAddress,
    this.longitude,
    this.latitude,
    this.locationType,
    required this.isActive,
    this.radiusMeters,
    this.timezone,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.description,
    this.createdDate,
    this.createdBy,
    this.modifiedDate,
    this.modifiedBy,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['ID'] ?? 0,
      locationName: json['LocationName'] ?? '',
      locationAddress: json['LocationAddress'],
      longitude: json['Longitude']?.toDouble(),
      latitude: json['Latitude']?.toDouble(),
      locationType: json['LocationType'],
      isActive: json['IsActive'] ?? true,
      radiusMeters: json['RadiusMeters'],
      timezone: json['Timezone'],
      contactPerson: json['ContactPerson'],
      contactPhone: json['ContactPhone'],
      contactEmail: json['ContactEmail'],
      description: json['Description'],
      createdDate: json['CreatedDate'] != null
          ? DateTime.parse(json['CreatedDate'])
          : null,
      createdBy: json['CreatedBy'],
      modifiedDate: json['ModifiedDate'] != null
          ? DateTime.parse(json['ModifiedDate'])
          : null,
      modifiedBy: json['ModifiedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID': id,
      'LocationName': locationName,
      'LocationAddress': locationAddress,
      'Longitude': longitude,
      'Latitude': latitude,
      'LocationType': locationType,
      'IsActive': isActive,
      'RadiusMeters': radiusMeters,
      'Timezone': timezone,
      'ContactPerson': contactPerson,
      'ContactPhone': contactPhone,
      'ContactEmail': contactEmail,
      'Description': description,
      'CreatedDate': createdDate?.toIso8601String(),
      'CreatedBy': createdBy,
      'ModifiedDate': modifiedDate?.toIso8601String(),
      'ModifiedBy': modifiedBy,
    };
  }
}

class LocationListResponse {
  final bool success;
  final String message;
  final List<LocationModel> locations;
  final int totalCount;

  LocationListResponse({
    required this.success,
    required this.message,
    required this.locations,
    required this.totalCount,
  });

  factory LocationListResponse.fromJson(Map<String, dynamic> json) {
    return LocationListResponse(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      locations: (json['Locations'] as List<dynamic>?)
              ?.map((location) => LocationModel.fromJson(location))
              .toList() ??
          [],
      totalCount: json['TotalCount'] ?? 0,
    );
  }
}

class EmployeeAssignedLocation {
  final int locationId;
  final String locationName;
  final String? locationAddress;
  final double? longitude;
  final double? latitude;
  final int? radiusMeters;
  final bool isActive;

  EmployeeAssignedLocation({
    required this.locationId,
    required this.locationName,
    this.locationAddress,
    this.longitude,
    this.latitude,
    this.radiusMeters,
    required this.isActive,
  });

  factory EmployeeAssignedLocation.fromJson(Map<String, dynamic> json) {
    return EmployeeAssignedLocation(
      locationId: json['LocationID'] ?? json['locationId'] ?? 0,
      locationName: json['LocationName'] ?? json['locationName'] ?? '',
      locationAddress: json['LocationAddress'] ?? json['locationAddress'],
      longitude: (json['Longitude'] ?? json['longitude']) is num
          ? (json['Longitude'] ?? json['longitude']).toDouble()
          : double.tryParse((json['Longitude'] ?? json['longitude'] ?? '').toString()),
      latitude: (json['Latitude'] ?? json['latitude']) is num
          ? (json['Latitude'] ?? json['latitude']).toDouble()
          : double.tryParse((json['Latitude'] ?? json['latitude'] ?? '').toString()),
      radiusMeters: json['RadiusMeters'] ?? json['radiusMeters'],
      isActive: json['IsActive'] ?? json['isActive'] ?? true,
    );
  }
}
