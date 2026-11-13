import 'package:dio/dio.dart';
import '../config/env.dart';
import '../storage/secure_storage.dart';

class DioClient {
  final Dio dio;
  final SecureStorage storage;

  // Separate client without interceptors, only used to refresh the access token
  final Dio refreshDio;

  // Called when the session can't be refreshed (the tokens are already cleared)
  final void Function()? onSessionExpired;

  // Refresh in progress, shared by every request that gets a 401 meanwhile
  Future<String?>? _refreshing;

  static const _kRetried = 'auth_retried';
  static const _noRefreshPaths = [
    '/auth/login/',
    '/auth/register/',
    '/auth/token/refresh/',
  ];

  DioClient(this.storage, {this.onSessionExpired})
      : dio = Dio(_baseOptions()),
        refreshDio = Dio(_baseOptions()) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));

    // Logs every request to the terminal to debug the API calls
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    // Access token expired (401): refresh it and retry the request once
    dio.interceptors.add(InterceptorsWrapper(onError: _onError));
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      );

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final sentAuth = options.headers['Authorization'];
    final path = options.uri.path;

    if (err.response?.statusCode != 401 ||
        sentAuth == null ||
        options.extra[_kRetried] == true ||
        _noRefreshPaths.any((p) => path.endsWith(p))) {
      handler.next(err);
      return;
    }

    final current = await storage.accessToken;
    if (current == null) {
      // Logged out (or session expired) while this request was running
      handler.next(err);
      return;
    }

    // If another request already refreshed the token, just retry with it
    final token =
        sentAuth == 'Bearer $current' ? await _refreshAccessToken() : current;
    if (token == null) {
      handler.next(err);
      return;
    }

    final retry = options.copyWith(
      // A FormData body can only be sent once, so send a copy
      data: options.data is FormData
          ? (options.data as FormData).clone()
          : options.data,
      extra: {...options.extra, _kRetried: true},
    );
    retry.headers['Authorization'] = 'Bearer $token';

    try {
      handler.resolve(await dio.fetch(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refreshAccessToken() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  // Returns the new access token, or null if the session couldn't be refreshed
  Future<String?> _refresh() async {
    final refresh = await storage.refreshToken;
    if (refresh != null) {
      try {
        final res = await refreshDio.post('/auth/token/refresh/', data: {
          'refresh': refresh,
        });
        final access = (res.data as Map<String, dynamic>)['access'] as String;
        await storage.saveTokens(access: access, refresh: refresh);
        return access;
      } on DioException catch (e) {
        // No answer from the server (offline, timeout): keep the session
        if (e.response == null) return null;
      } catch (_) {
        // Unexpected response body: treated like a rejected refresh
      }
    }

    await storage.clear();
    onSessionExpired?.call();
    return null;
  }
}
