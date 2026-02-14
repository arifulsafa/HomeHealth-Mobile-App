import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import '../../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String get baseUrl => _dio.options.baseUrl;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectionTimeout),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests
          final token = await _storage.read(key: AppConstants.keyAuthToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          AppLogger.e('API Error: ${error.message}');
          
          if (error.response?.statusCode == 401) {
            // Handle unauthorized - clear tokens and redirect to login
            _handleUnauthorized();
          }
          
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> _handleUnauthorized() async {
    await _storage.delete(key: AppConstants.keyAuthToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
    // TODO: Navigate to login screen
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> postMultipart(
    String path, {
    required FormData formData,
    Function(int, int)? onSendProgress,
    Options? options,
  }) async {
    try {
      // Override Content-Type for multipart uploads
      final uploadOptions = options ?? Options();
      final headers = <String, dynamic>{
        ...?uploadOptions.headers,
        'Content-Type': 'multipart/form-data',
      };
      
      return await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: uploadOptions.copyWith(headers: headers),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Failure _handleError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return NetworkFailure('Connection timeout');
    }

    if (error.type == DioExceptionType.connectionError) {
      return NetworkFailure('No internet connection');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final message = error.response!.data?['message'] ?? 'Unknown error';

      if (statusCode == 401) {
        return AuthenticationFailure('Unauthorized: $message');
      }

      return ServerFailure('Server error ($statusCode): $message');
    }

    return NetworkFailure('Network error: ${error.message}');
  }
}
