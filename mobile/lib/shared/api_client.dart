import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/api_exception.dart';
import '../core/env.dart';
import '../core/secure_storage.dart';

/// The one Dio instance the whole app shares (per CLAUDE.md: "the shared
/// Flutter api_client.dart" is a coordination point -- don't create a second
/// one per feature). Attaches the access token to every request and, on a
/// 401, tries exactly one silent refresh before giving up and asking the
/// caller to sign back in.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.instance.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
        if (error.response?.statusCode == 401 && !isAuthEndpoint && !_isRetry(error.requestOptions)) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final retryOptions = error.requestOptions;
            retryOptions.extra['retried'] = true;
            final token = await SecureStorage.instance.accessToken;
            retryOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(retryOptions);
              handler.resolve(response);
              return;
            } catch (_) {
              // fall through to normal error handling
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  bool _isRetry(RequestOptions options) => options.extra['retried'] == true;

  Future<bool> _tryRefresh() async {
    final refreshToken = await SecureStorage.instance.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = response.data as Map<String, dynamic>;
      await SecureStorage.instance.saveAccessToken(data['accessToken'] as String);
      return true;
    } catch (_) {
      await SecureStorage.instance.clear();
      return false;
    }
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return _wrap(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    return _wrap(() => _dio.post<T>(path, data: data));
  }

  Future<Response<T>> put<T>(String path, {Object? data}) async {
    return _wrap(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) async {
    return _wrap(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path) async {
    return _wrap(() => _dio.delete<T>(path));
  }

  /// Phase 10 -- subscribes to a backend Server-Sent Events endpoint and
  /// yields decoded JSON payloads from each `data:` block. Deliberately a
  /// minimal hand-rolled SSE parser (event/data/blank-line framing, `:`
  /// comment lines ignored) rather than a new pub dependency -- this app
  /// only needs one SSE consumer today (live bed availability).
  Stream<Map<String, dynamic>> sseStream(String path) async* {
    final response = await _dio.get<ResponseBody>(
      path,
      options: Options(responseType: ResponseType.stream, headers: {'Accept': 'text/event-stream'}),
    );

    final lines = response.data!.stream.transform(utf8.decoder).transform(const LineSplitter());
    final dataBuffer = StringBuffer();

    await for (final line in lines) {
      if (line.startsWith(':')) {
        continue; // heartbeat/comment line -- see BedAvailabilityBroadcaster.heartbeat on the backend
      }
      if (line.startsWith('data:')) {
        dataBuffer.write(line.substring(5).trim());
        continue;
      }
      if (line.isEmpty && dataBuffer.isNotEmpty) {
        final raw = dataBuffer.toString();
        dataBuffer.clear();
        try {
          yield jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          // malformed event -- skip rather than breaking the stream
        }
      }
    }
  }

  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException(
        message: (data['message'] as String?) ?? 'Something went wrong',
        statusCode: e.response?.statusCode,
        details: (data['details'] as List?)?.cast<String>() ?? const [],
      );
    }
    return ApiException(
      message: e.message ?? 'Network error. Check your connection.',
      statusCode: e.response?.statusCode,
    );
  }
}
