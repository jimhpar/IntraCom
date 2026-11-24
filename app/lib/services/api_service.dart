import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Live Oracle Cloud Server Endpoint
  static const String baseUrl = 'http://129.225.125.127:8080';
  static const String wsUrl = 'ws://129.225.125.127:8080/ws';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userNum = prefs.getString('user_number');
    final userName = prefs.getString('user_name');
    final userDistrict = prefs.getString('user_district');

    if (_token != null && userNum != null) {
      _currentUser = {
        'full_number': userNum,
        'display_name': userName ?? 'User',
        'district_name': userDistrict ?? '',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required int districtCode,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'display_name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'district_code': districtCode,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _saveSession(data);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Registration failed'};
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    }
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _saveSession(data);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Login failed'};
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Network error';
      return {'success': false, 'error': msg};
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token = data['token'];
    _currentUser = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
    await prefs.setString('user_number', data['full_number'] ?? '');
    await prefs.setString('user_name', data['display_name'] ?? '');
    await prefs.setString('user_district', data['district_name'] ?? '');
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
