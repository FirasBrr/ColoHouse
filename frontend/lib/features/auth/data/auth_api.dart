import 'package:dio/dio.dart';
import '../../../core/errors/auth_exception.dart';
import '../models/user.dart';
import '../../profile/models/roommate_preferences.dart';
import '../../housing/models/listing.dart';
import '../../housing/models/housing_request.dart';
import '../../housing/models/listing_filters.dart';

class AuthApi {
  final Dio dio;
  AuthApi(this.dio);

  // ---------------- AUTH ----------------
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await dio.post('/auth/register/', data: {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
      });
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<Map<String, String>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      return {
        'access': data['access'] as String,
        'refresh': data['refresh'] as String,
      };
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- LISTINGS ----------------
  Future<int> createListing({
    required String title,
    required String description,
    required int rent,
    required int deposit,
    required String roomType,
    required int cityId,
    required String address,
    required double latitude,
    required double longitude,
    required String availableFrom,
    String rules = '',
  }) async {
    try {
      final res = await dio.post('/listings/', data: {
        'title': title,
        'description': description,
        'rent': rent,
        'deposit': deposit,
        'room_type': roomType,
        'city_id': cityId,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'available_from': availableFrom,
        'rules': rules,
        'status': 'active',
      });
      return res.data['id'] as int; 
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // Search active listings. `filters` adds the Sprint 2 search filters (its q wins over `query`)
  Future<List<HousingListing>> getListings({String? query, ListingFilters? filters}) async {
    try {
      final res = await dio.get('/listings/', queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        ...?filters?.toQueryParameters(),
      });
      return (res.data as List)
          .map((e) => HousingListing.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  } 

  // Photo upload (Android path based)
  Future<void> uploadListingPhoto(int listingId, String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath, filename: 'photo.jpg'),
      });
      await dio.post('/listings/$listingId/photos/', data: formData);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
    // Delete a specific photo from a listing
  Future<void> deleteListingPhoto(int listingId, int photoId) async {
    try {
      await dio.delete('/listings/$listingId/photos/$photoId/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
    // Upload multiple photos for a listing
  Future<void> uploadMultiplePhotos(int listingId, List<String> filePaths) async {
    for (final path in filePaths) {
      try {
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(path, filename: 'photo.jpg'),
        });
        await dio.post('/listings/$listingId/photos/', data: formData);
      } on DioException catch (e) {
        // If one fails, continue with the others, or throw
        throw AuthException(_errorMessage(e));
      }
    }
  }
  Future<void> updateListing(int id, Map<String, dynamic> changes) async {
    try {
      await dio.patch('/listings/$id/', data: changes);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // Delete a listing (using the 'closed' status)
  Future<void> deleteListing(int id) async {
    try {
      // Backend doesn't allow DELETE, so we set status to 'closed'
      await dio.patch('/listings/$id/', data: {'status': 'closed'});
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
  Future<List<HousingListing>> getMyListings() async {
    try {
      final res = await dio.get('/listings/mine/');
      return (res.data as List)
          .map((e) => HousingListing.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

    // Fetch requests sent to my listings
  Future<List<HousingRequest>> getReceivedRequests() async {
    try {
      final res = await dio.get('/requests/received/');
      return (res.data as List)
          .map((e) => HousingRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
  // Fetch requests I have sent to others
  Future<List<HousingRequest>> getSentRequests() async {
    try {
      final res = await dio.get('/requests/sent/');
      return (res.data as List)
          .map((e) => HousingRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // Cancel a request I sent
  Future<void> cancelRequest(int requestId) async {
    try {
      await dio.post('/requests/$requestId/cancel/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
  // Accept a request
  Future<void> acceptRequest(int requestId) async {
    try {
      await dio.post('/requests/$requestId/accept/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // Decline a request
  Future<void> declineRequest(int requestId) async {
    try {
      await dio.post('/requests/$requestId/decline/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- ME ----------------
  Future<User> me() async {
    try {
      final res = await dio.get('/auth/me/');
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<String> refresh(String refreshToken) async {
    try {
      final res = await dio.post('/auth/token/refresh/', data: {
        'refresh': refreshToken,
      });
      return (res.data as Map<String, dynamic>)['access'] as String;
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- PROFILE ----------------
  Future<User> updateProfile(Map<String, dynamic> changes) async {
    try {
      final res = await dio.patch('/auth/me/', data: changes);
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await dio.delete('/auth/me/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
  // Upload a profile picture
  Future<void> uploadProfilePicture(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'profile_picture': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
      });
      
      // Note: PATCH request with multipart data
      await dio.patch(
        '/auth/me/', 
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- PREFERENCES ----------------
  Future<RoommatePreferences> getPreferences() async {
    try {
      final res = await dio.get('/auth/me/preferences/');
      return RoommatePreferences.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<RoommatePreferences> updatePreferences(Map<String, dynamic> changes) async {
    try {
      final res = await dio.patch('/auth/me/preferences/', data: changes);
      return RoommatePreferences.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- CITIES ----------------
  Future<List<City>> listCities() async {
    try {
      final res = await dio.get('/cities/');
      return (res.data as List)
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- ERRORS ----------------
  String _errorMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (status == 401) {
      if (data is Map && data['detail'] is String) return data['detail'];
      return 'Invalid email or password.';
    }

    if (status == 400 && data is Map) {
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Is the backend running?';
    }

    return 'Something went wrong. Try again.';
  }
  // Get a single listing by ID
  Future<HousingListing> getListingDetails(int id) async {
    try {
      final res = await dio.get('/listings/$id/');
      return HousingListing.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // Send a housing request
  Future<void> sendRequest(int listingId, String message) async {
    try {
      await dio.post('/listings/$listingId/requests/', data: {
        'message': message,
      });
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }
}