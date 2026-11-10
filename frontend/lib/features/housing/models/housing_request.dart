class RequestListingSummary {
  final int id;
  final String title;
  final int rent;
  final String roomType;
  final String city;
  final String? photo;

  RequestListingSummary({
    required this.id,
    required this.title,
    required this.rent,
    required this.roomType,
    required this.city,
    this.photo,
  });

  factory RequestListingSummary.fromJson(Map<String, dynamic> json) {
    return RequestListingSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      rent: json['rent'] as int? ?? 0,
      roomType: json['room_type'] as String? ?? '',
      city: json['city'] as String? ?? '',
      photo: json['photo'] as String?,
    );
  }
}

class HousingRequest {
  final int id;
  final RequestListingSummary listing;
  final String senderName;
  final String ownerName;
  final String message;
  final String status; // 'pending', 'accepted', 'declined', 'cancelled'
  final Map<String, dynamic>? contact; // Holds address, phones when accepted

  HousingRequest({
    required this.id,
    required this.listing,
    required this.senderName,
    required this.ownerName,
    required this.message,
    required this.status,
    this.contact,
  });

  factory HousingRequest.fromJson(Map<String, dynamic> json) {
    return HousingRequest(
      id: json['id'] as int,
      listing: RequestListingSummary.fromJson(json['listing'] as Map<String, dynamic>),
      senderName: '${json['sender']?['first_name'] ?? ''} ${json['sender']?['last_name'] ?? ''}'.trim(),
      ownerName: '${json['owner']?['first_name'] ?? ''} ${json['owner']?['last_name'] ?? ''}'.trim(),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      contact: json['contact'] as Map<String, dynamic>?,
    );
  }
}