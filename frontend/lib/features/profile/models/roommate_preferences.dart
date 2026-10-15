class RoommatePreferences {
  final int? budget;
  final String preferredRoomType; // 'private' | 'shared' | 'studio' | ''
  final DateTime? moveInDate;
  final double? maxDistanceToCenter; // renamed from maxDistanceToCampus
  final String sleepSchedule; // 'early' | 'normal' | 'late' | ''
  final int? noiseTolerance; // 1–5
  final int? cleanliness; // 1–5
  final bool smoker;
  final bool acceptsSmokers;
  final bool lookingForRoom;

  RoommatePreferences({
    required this.budget,
    required this.preferredRoomType,
    required this.moveInDate,
    required this.maxDistanceToCenter,
    required this.sleepSchedule,
    required this.noiseTolerance,
    required this.cleanliness,
    required this.smoker,
    required this.acceptsSmokers,
    required this.lookingForRoom,
  });

  factory RoommatePreferences.empty() => RoommatePreferences(
        budget: null,
        preferredRoomType: '',
        moveInDate: null,
        maxDistanceToCenter: null,
        sleepSchedule: '',
        noiseTolerance: null,
        cleanliness: null,
        smoker: false,
        acceptsSmokers: true,
        lookingForRoom: false,
      );

  factory RoommatePreferences.fromJson(Map<String, dynamic> json) =>
      RoommatePreferences(
        budget: json['budget'] as int?,
        preferredRoomType: json['preferred_room_type'] as String? ?? '',
        moveInDate: json['move_in_date'] == null
            ? null
            : DateTime.tryParse(json['move_in_date'] as String),
        maxDistanceToCenter:
            (json['max_distance_to_center'] as num?)?.toDouble(),
        sleepSchedule: json['sleep_schedule'] as String? ?? '',
        noiseTolerance: json['noise_tolerance'] as int?,
        cleanliness: json['cleanliness'] as int?,
        smoker: json['smoker'] as bool? ?? false,
        acceptsSmokers: json['accepts_smokers'] as bool? ?? true,
        lookingForRoom: json['looking_for_room'] as bool? ?? false,
      );

  Map<String, dynamic> toPatchJson() => {
        'budget': budget,
        'preferred_room_type': preferredRoomType,
        'move_in_date':
            moveInDate?.toIso8601String().substring(0, 10),
        'max_distance_to_center': maxDistanceToCenter, // renamed
        'sleep_schedule': sleepSchedule,
        'noise_tolerance': noiseTolerance,
        'cleanliness': cleanliness,
        'smoker': smoker,
        'accepts_smokers': acceptsSmokers,
        'looking_for_room': lookingForRoom,
      };
}