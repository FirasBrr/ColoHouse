/// What the API shows about another person (no email, no phone).
class PublicUser {
  final int id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String bio;
  final String institution;
  final String occupation;
  final bool isVerified;

  PublicUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.bio = '',
    this.institution = '',
    this.occupation = '',
    this.isVerified = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? '?' : value;
  }

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
        id: json['id'] as int,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        profilePicture: json['profile_picture'] as String?,
        bio: json['bio'] as String? ?? '',
        institution: json['institution'] as String? ?? '',
        occupation: json['occupation'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
      );
}
