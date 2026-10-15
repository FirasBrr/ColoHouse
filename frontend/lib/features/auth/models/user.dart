class City {
  final int id;
  final String name;
  final String region;
  final String address;
  final double latitude;
  final double longitude;

  City({
    required this.id,
    required this.name,
    required this.region,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        region: json['region'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      );
}

class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String? profilePicture;
  final String bio;
  final String institution;
  final String occupation;
  final City? city;
  final bool isVerified;
  final bool pushEnabled;
  final bool notifyRequests;
  final bool notifyMessages;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.profilePicture,
    required this.bio,
    required this.institution,
    required this.occupation,
    required this.city,
    required this.isVerified,
    required this.pushEnabled,
    required this.notifyRequests,
    required this.notifyMessages,
  });

  String get fullName => '$firstName $lastName'.trim();

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? bio,
    String? institution,
    String? occupation,
    City? city,
    bool clearCity = false,
    String? profilePicture,
    bool? isVerified,
    bool? pushEnabled,
    bool? notifyRequests,
    bool? notifyMessages,
  }) =>
      User(
        id: id,
        email: email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        profilePicture: profilePicture ?? this.profilePicture,
        bio: bio ?? this.bio,
        institution: institution ?? this.institution,
        occupation: occupation ?? this.occupation,
        city: clearCity ? null : (city ?? this.city),
        isVerified: isVerified ?? this.isVerified,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        notifyRequests: notifyRequests ?? this.notifyRequests,
        notifyMessages: notifyMessages ?? this.notifyMessages,
      );

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        profilePicture: json['profile_picture'] as String?,
        bio: json['bio'] as String? ?? '',
        institution: json['institution'] as String? ?? '',
        occupation: json['occupation'] as String? ?? '',
        city: json['city'] == null
            ? null
            : City.fromJson(json['city'] as Map<String, dynamic>),
        isVerified: json['is_verified'] as bool? ?? false,
        pushEnabled: json['push_enabled'] as bool? ?? true,
        notifyRequests: json['notify_requests'] as bool? ?? true,
        notifyMessages: json['notify_messages'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'profile_picture': profilePicture,
        'bio': bio,
        'institution': institution,
        'occupation': occupation,
        'city': city == null
            ? null
            : {
                'id': city!.id,
                'name': city!.name,
                'region': city!.region,
                'address': city!.address,
                'latitude': city!.latitude,
                'longitude': city!.longitude,
              },
        'is_verified': isVerified,
        'push_enabled': pushEnabled,
        'notify_requests': notifyRequests,
        'notify_messages': notifyMessages,
      };
}