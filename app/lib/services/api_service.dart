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
  bool get isAdmin => _currentUser?['is_admin'] == true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userNum = prefs.getString('user_number');
    final userName = prefs.getString('user_name');
    final userDistrict = prefs.getString('user_district');
    final userBio = prefs.getString('user_bio');
    final isAdminVal = prefs.getBool('is_admin') ?? false;

    if (_token != null && userNum != null) {
      _currentUser = {
        'full_number': userNum,
        'display_name': userName ?? 'User',
        'district_name': userDistrict ?? '',
        'bio': userBio ?? '',
        'is_admin': isAdminVal,
      };
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    required String phone,
    required String password,
    required int districtCode,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/register', data: {
        'display_name': name,
        'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
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
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('auth_token', _token!);
    await prefs.setString('user_number', data['full_number'] ?? '');
    await prefs.setString('user_name', data['display_name'] ?? '');
    await prefs.setString('user_district', data['district_name'] ?? '');
    await prefs.setString('user_bio', data['bio'] ?? '');
    await prefs.setBool('is_admin', data['is_admin'] == true);
  }

  Future<Map<String, dynamic>> updateProfile({String? displayName, String? bio}) async {
    try {
      final response = await _dio.put('/api/v1/users/me', data: {
        'display_name': ?displayName,
        'bio': ?bio,
      });
      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && _currentUser != null) {
          _currentUser!['display_name'] = data['display_name'] ?? _currentUser!['display_name'];
          _currentUser!['bio'] = data['bio'] ?? _currentUser!['bio'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', _currentUser!['display_name'] ?? '');
          await prefs.setString('user_bio', _currentUser!['bio'] ?? '');
        }
        return {'success': true, 'message': response.data['message'] ?? 'Profile updated'};
      }
      return {'success': false, 'error': response.data['error'] ?? 'Update failed'};
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data?['error'] ?? e.message ?? 'Network error'};
    }
  }

  // Admin APIs
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await _dio.get('/api/v1/admin/stats');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminUsers({String? query}) async {
    try {
      final res = await _dio.get('/api/v1/admin/users', queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminToggleSuspend(String userId) async {
    try {
      final res = await _dio.put('/api/v1/admin/users/$userId/suspend');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminHubRequests() async {
    try {
      final res = await _dio.get('/api/v1/admin/hub-requests');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminReviewHubRequest(String requestId, String action, {String note = ''}) async {
    try {
      final res = await _dio.post('/api/v1/admin/hub-requests/$requestId/review', data: {
        'action': action,
        'note': note,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminBanUserFromHub(String hubId, String userNumber, {String reason = ''}) async {
    try {
      final res = await _dio.post('/api/v1/admin/hubs/$hubId/bans', data: {
        'user_number': userNumber,
        'reason': reason,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Hangouts APIs
  Future<Map<String, dynamic>> getPublicHubs() async {
    try {
      final res = await _dio.get('/api/v1/hangouts/public');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> requestPublicHub({required String name, required String description, required int districtCode}) async {
    try {
      final res = await _dio.post('/api/v1/hangouts/request-public', data: {
        'name': name,
        'description': description,
        'district_code': districtCode,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPrivateTables() async {
    try {
      final res = await _dio.get('/api/v1/hangouts/private');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createPrivateTable({
    required String name,
    required String description,
    required List<String> memberNumbers,
  }) async {
    try {
      final res = await _dio.post('/api/v1/hangouts/private', data: {
        'name': name,
        'description': description,
        'member_numbers': memberNumbers,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
