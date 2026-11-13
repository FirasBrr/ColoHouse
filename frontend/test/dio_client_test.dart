import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_colohouse/core/network/dio_client.dart';
import 'package:front_colohouse/core/storage/secure_storage.dart';

// In-memory storage, so the tests don't need the platform secure storage
class FakeStorage implements SecureStorage {
  String? access;
  String? refresh;
  FakeStorage({this.access, this.refresh});

  @override
  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

typedef Responder = Future<ResponseBody> Function(
    RequestOptions options, String body);

// Answers every request with [respond] instead of going to the network
class FakeAdapter implements HttpClientAdapter {
  final Responder respond;
  final List<RequestOptions> requests = [];
  FakeAdapter(this.respond);

  int countFor(String path) =>
      requests.where((r) => r.uri.path.endsWith(path)).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return respond(options, utf8.decode(bytes, allowMalformed: true));
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, int status) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late FakeStorage storage;
  late int expiredCalls;

  DioClient makeClient(FakeAdapter adapter) {
    final client = DioClient(storage, onSessionExpired: () => expiredCalls++);
    client.dio.httpClientAdapter = adapter;
    client.refreshDio.httpClientAdapter = adapter;
    // Keep the test output readable
    client.dio.interceptors.removeWhere((i) => i is LogInterceptor);
    return client;
  }

  // Protected endpoints accept only 'new-access'; refresh gives 'new-access'
  Future<ResponseBody> server(RequestOptions o, String body,
      {int refreshStatus = 200}) async {
    if (o.uri.path.endsWith('/auth/token/refresh/')) {
      // Small delay so concurrent 401s overlap with the refresh
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshStatus != 200) {
        return jsonBody(
            {'detail': 'Token is invalid or expired'}, refreshStatus);
      }
      return jsonBody({'access': 'new-access'}, 200);
    }
    if (o.uri.path.endsWith('/auth/login/')) {
      return jsonBody({'detail': 'No active account found'}, 401);
    }
    if (o.headers['Authorization'] == 'Bearer new-access') {
      return jsonBody({'ok': true, 'body': body}, 200);
    }
    return jsonBody({'detail': 'Token is invalid or expired'}, 401);
  }

  setUp(() {
    storage = FakeStorage(access: 'old-access', refresh: 'refresh-1');
    expiredCalls = 0;
  });

  test('401 -> refresh -> retry succeeds and the new token is saved', () async {
    final adapter = FakeAdapter(server);
    final client = makeClient(adapter);

    final res = await client.dio.get('/auth/me/');

    expect(res.statusCode, 200);
    expect(res.data['ok'], true);
    expect(adapter.countFor('/auth/token/refresh/'), 1);
    expect(adapter.countFor('/auth/me/'), 2);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new-access');
    expect(storage.access, 'new-access');
    expect(storage.refresh, 'refresh-1');
    expect(expiredCalls, 0);

    final refreshCall = adapter.requests
        .firstWhere((r) => r.uri.path.endsWith('/auth/token/refresh/'));
    expect(refreshCall.headers['Authorization'], isNull);
  });

  test('concurrent 401s trigger exactly one refresh', () async {
    final adapter = FakeAdapter(server);
    final client = makeClient(adapter);

    final results = await Future.wait([
      client.dio.get('/listings/'),
      client.dio.get('/auth/me/'),
      client.dio.get('/requests/sent/'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(adapter.countFor('/auth/token/refresh/'), 1);
    expect(storage.access, 'new-access');
    expect(expiredCalls, 0);
  });

  test('refresh fails -> session expired once and storage cleared', () async {
    final adapter = FakeAdapter((o, b) => server(o, b, refreshStatus: 401));
    final client = makeClient(adapter);

    final results = await Future.wait([
      client.dio.get('/listings/').then<Object>((r) => r, onError: (e) => e),
      client.dio.get('/auth/me/').then<Object>((r) => r, onError: (e) => e),
    ]);

    for (final r in results) {
      expect(r, isA<DioException>());
      expect((r as DioException).response?.statusCode, 401);
    }
    expect(adapter.countFor('/auth/token/refresh/'), 1);
    expect(expiredCalls, 1);
    expect(storage.access, isNull);
    expect(storage.refresh, isNull);
  });

  test('no refresh token -> session expired, no refresh call', () async {
    storage = FakeStorage(access: 'old-access');
    final adapter = FakeAdapter(server);
    final client = makeClient(adapter);

    await expectLater(
        client.dio.get('/auth/me/'), throwsA(isA<DioException>()));

    expect(adapter.countFor('/auth/token/refresh/'), 0);
    expect(expiredCalls, 1);
    expect(storage.access, isNull);
  });

  test('a 401 from /auth/login/ is not retried', () async {
    final adapter = FakeAdapter(server);
    final client = makeClient(adapter);

    await expectLater(
      client.dio
          .post('/auth/login/', data: {'email': 'a@b.c', 'password': 'x'}),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'status', 401)),
    );

    expect(adapter.countFor('/auth/login/'), 1);
    expect(adapter.countFor('/auth/token/refresh/'), 0);
    expect(expiredCalls, 0);
    expect(storage.access, 'old-access');
    expect(storage.refresh, 'refresh-1');
  });

  test('a request is retried only once', () async {
    // Refresh works but the endpoint keeps answering 401
    final adapter = FakeAdapter((o, b) async {
      if (o.uri.path.endsWith('/auth/token/refresh/')) {
        return jsonBody({'access': 'new-access'}, 200);
      }
      return jsonBody({'detail': 'nope'}, 401);
    });
    final client = makeClient(adapter);

    await expectLater(
        client.dio.get('/auth/me/'), throwsA(isA<DioException>()));

    expect(adapter.countFor('/auth/me/'), 2);
    expect(adapter.countFor('/auth/token/refresh/'), 1);
    expect(expiredCalls, 0);
  });

  test('a multipart request is re-sent with its body', () async {
    final adapter = FakeAdapter(server);
    final client = makeClient(adapter);

    final form = FormData.fromMap({
      'caption': 'kitchen',
      'image': MultipartFile.fromBytes(utf8.encode('fake-image-bytes'),
          filename: 'photo.jpg'),
    });
    final res = await client.dio.post('/listings/1/photos/', data: form);

    expect(res.statusCode, 200);
    expect(res.data['body'], contains('kitchen'));
    expect(res.data['body'], contains('fake-image-bytes'));
    expect(adapter.countFor('/listings/1/photos/'), 2);
  });

  test('refresh with no answer from the server keeps the session', () async {
    final adapter = FakeAdapter((o, b) async {
      if (o.uri.path.endsWith('/auth/token/refresh/')) {
        throw DioException.connectionError(
            requestOptions: o, reason: 'offline');
      }
      return server(o, b);
    });
    final client = makeClient(adapter);

    await expectLater(
        client.dio.get('/auth/me/'), throwsA(isA<DioException>()));

    expect(expiredCalls, 0);
    expect(storage.access, 'old-access');
    expect(storage.refresh, 'refresh-1');
  });
}
