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
    final requestTimeout = Duration(seconds: Env.usesLocalBackend ? 15 : 90);
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      // Local failures should surface quickly; free hosted instances may need
      // substantially longer to wake after inactivity.
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
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
        if (error.response?.statusCode == 401 &&
            !isAuthEndpoint &&
            !_isRetry(error.requestOptions)) {
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

  /// Called once when the refresh token is rejected and the stored session
  /// has been cleared. AuthState registers here so the router can send the
  /// user back to sign-in; without it the app keeps rendering signed-in
  /// screens whose every request now 401s, with no way out but a restart.
  Future<void> Function()? onSessionExpired;

  /// The refresh in flight, if any. Several screens load in parallel, so a
  /// stale access token produces several simultaneous 401s; letting each one
  /// refresh separately means the second call presents an already-rotated
  /// refresh token, is rejected, and signs the user out mid-session.
  Future<bool>? _refreshInFlight;

  bool _isRetry(RequestOptions options) => options.extra['retried'] == true;

  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _refreshOnce().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _refreshOnce() async {
    final refreshToken = await SecureStorage.instance.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = response.data as Map<String, dynamic>;
      await SecureStorage.instance.saveRotatedTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      // Only the server actually rejecting the token ends the session. A
      // transport failure (no network, server asleep) or a 5xx is a bad
      // moment, not an expired session -- keep the tokens so the next
      // attempt can still refresh, instead of signing everyone out whenever
      // the backend hiccups.
      final status = e.response?.statusCode;
      if (status != 401 && status != 403) return false;
      await _endSession();
      return false;
    } catch (_) {
      // A malformed refresh response means we have no usable token either.
      await _endSession();
      return false;
    }
  }

  Future<void> _endSession() async {
    await SecureStorage.instance.clear();
    await onSessionExpired?.call();
  }

  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? queryParameters}) async {
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

  /// Backoff between reconnect attempts. A phone changes network constantly
  /// (wifi to mobile data, tunnel, screen off), and a free-tier backend
  /// recycles connections, so an SSE stream that gives up on the first drop
  /// is dead for the rest of the session.
  static const _sseBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];

  /// Phase 10 -- subscribes to a backend Server-Sent Events endpoint and
  /// yields decoded JSON payloads from each `data:` block, reconnecting with
  /// backoff whenever the connection drops until the caller cancels.
  ///
  /// [onConnected] reports the live/stale transition so callers can stop
  /// presenting the last snapshot as live once the stream is down.
  Stream<Map<String, dynamic>> sseStream(
    String path, {
    void Function(bool connected)? onConnected,
  }) async* {
    var attempt = 0;
    while (true) {
      var announced = false;
      try {
        await for (final event in _sseConnection(path)) {
          attempt = 0;
          if (!announced) {
            announced = true;
            onConnected?.call(true);
          }
          yield event;
        }
      } catch (_) {
        // Any transport failure is retried below, same as a clean close.
      }
      onConnected?.call(false);
      await Future<void>.delayed(_sseBackoff[
          attempt < _sseBackoff.length ? attempt : _sseBackoff.length - 1]);
      attempt++;
    }
  }

  /// One SSE connection, ending when the server closes it. Deliberately a
  /// minimal hand-rolled parser (event/data/blank-line framing, `:` comment
  /// lines ignored) rather than a new pub dependency.
  Stream<Map<String, dynamic>> _sseConnection(String path) async* {
    final response = await _dio.get<ResponseBody>(
      path,
      // Unlike regular API calls, an SSE connection is meant to stay open
      // indefinitely between heartbeats -- the shared 15s receiveTimeout
      // (fine for normal requests) would otherwise abort it as soon as the
      // server goes quiet for that long.
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        receiveTimeout: Duration.zero,
      ),
    );

    // Dio exposes SSE chunks as Uint8List. Cast to List<int> first because
    // StreamTransformer is invariant in its input type, while utf8.decoder
    // accepts List<int> rather than the narrower Uint8List.
    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
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
      final details =
          (data['details'] as List?)?.whereType<String>().toList() ??
              const <String>[];
      final serverMessage =
          (data['message'] as String?) ?? 'Something went wrong';
      return ApiException(
        // Bean-validation responses have a deliberately generic summary. If
        // a future client/server contract ever drifts again, show the precise
        // rejected field instead of the unhelpful "Request validation failed".
        message:
            serverMessage == 'Request validation failed' && details.isNotEmpty
                ? details.join('\n')
                : serverMessage,
        statusCode: e.response?.statusCode,
        details: details,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException(
        message: Env.usesLocalBackend
            ? 'Cannot reach the local backend. Make sure PostgreSQL and Spring Boot are running on port 8080.'
            : 'The server is taking longer than expected to wake up. Please wait a moment and try again.',
        statusCode: e.response?.statusCode,
      );
    }
    return ApiException(
      message: e.message ?? 'Network error. Check your connection.',
      statusCode: e.response?.statusCode,
    );
  }
}
