class ListingPhoto {
  final int id;
  final String image;

  ListingPhoto({required this.id, required this.image});

  factory ListingPhoto.fromJson(Map<String, dynamic> json) => ListingPhoto(
        id: json['id'] as int,
        image: json['image'] as String,
      );
}

class HousingListing {
  final int id;
  final int ownerId; // ADDED
  final String title;
  final String description;
  final int rent;
  final int deposit;
  final String roomType;
  final String cityName;
  final String? address;
  final double latitude;
  final double longitude;
  final String availableFrom;
  final String status;
  final List<ListingPhoto> photos;
  final String ownerName;
  final bool isVerifiedOwner;
  final double? distanceKm;
  final bool contactVisible;
  final String? ownerPhone;
  final String rules; // ADDED

  HousingListing({
    required this.id,
    required this.ownerId, // ADDED
    required this.title,
    required this.description,
    required this.rent,
    required this.deposit,
    required this.roomType,
    required this.cityName,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.availableFrom,
    required this.status,
    required this.photos,
    required this.ownerName,
    required this.isVerifiedOwner,
    this.distanceKm,
    required this.contactVisible,
    this.ownerPhone,
    required this.rules, // ADDED
  });

  factory HousingListing.fromJson(Map<String, dynamic> json) {
    return HousingListing(
      id: json['id'] as int,
      ownerId: json['owner']?['id'] as int? ?? 0, // ADDED
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rent: json['rent'] as int? ?? 0,
      deposit: json['deposit'] as int? ?? 0,
      roomType: json['room_type'] as String? ?? '',
      cityName: json['city']?['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      availableFrom: json['available_from'] as String? ?? '',
      status: json['status'] as String? ?? '',
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => ListingPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      ownerName: '${json['owner']?['first_name'] ?? ''} ${json['owner']?['last_name'] ?? ''}'.trim(),
      isVerifiedOwner: json['owner']?['is_verified'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      contactVisible: json['contact_visible'] as bool? ?? false,
      ownerPhone: json['owner_phone'] as String?,
      rules: json['rules'] as String? ?? '', // ADDED
    );
  }
}