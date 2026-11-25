import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Live Oracle Cloud Server Endpoint - dynamically adapts to current origin (HTTP or HTTPS)
  static String get baseUrl {
    if (kIsWeb) {
      final loc = Uri.base;
      final portPart = (loc.port == 80 || loc.port == 443 || loc.port == 0) ? '' : ':${loc.port}';
      return '${loc.scheme}://${loc.host}$portPart';
    }
    return 'https://129.225.125.127';
  }

  static String get wsUrl {
    if (kIsWeb) {
      final loc = Uri.base;
      final wsScheme = loc.scheme == 'https' ? 'wss' : 'ws';
      final portPart = (loc.port == 80 || loc.port == 443 || loc.port == 0) ? '' : ':${loc.port}';
      return '$wsScheme://${loc.host}$portPart/ws';
    }
    return 'wss://129.225.125.127/ws';
  }

  late final Dio _dio = Dio(BaseOptions(
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

  // Fetch the latest profile from server and synchronize local storage
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final res = await _dio.get('/api/v1/users/me');
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        _currentUser = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_number', data['full_number'] ?? '');
        await prefs.setString('user_name', data['display_name'] ?? '');
        await prefs.setString('user_district', data['district_name'] ?? '');
        await prefs.setString('user_bio', data['bio'] ?? '');
        await prefs.setBool('is_admin', data['is_admin'] == true);
        return data;
      }
    } catch (_) {}
    return _currentUser;
  }

  // Change user password
  Future<Map<String, dynamic>> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      final res = await _dio.put('/api/v1/users/change-password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
      return res.data;
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data?['error'] ?? e.message ?? 'Network error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Fetch live online user numbers
  Future<List<String>> getOnlineUsers() async {
    try {
      final res = await _dio.get('/api/v1/users/online');
      if (res.data['success'] == true && res.data['data'] is List) {
        return (res.data['data'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  // Full admin edit for any user
  Future<Map<String, dynamic>> adminUpdateUserFull(String userId, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/api/v1/admin/users/$userId', data: data);
      return res.data;
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data?['error'] ?? e.message ?? 'Failed to update user'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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

  Future<Map<String, dynamic>> adminUpdateUserNumber(String userId, String fullNumber) async {
    try {
      final res = await _dio.put('/api/v1/admin/users/$userId/number', data: {
        'full_number': fullNumber,
      });
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

  // Get users belonging to a Hub / Private Table
  Future<List<Map<String, dynamic>>> getHubMembers(String hubId) async {
    try {
      final res = await _dio.get('/api/v1/hangouts/$hubId/members');
      if (res.data['success'] == true && res.data['data'] is List) {
        return List<Map<String, dynamic>>.from(res.data['data']);
      }
    } catch (_) {}
    return [];
  }

  // Get Chat Messages for a Hub
  Future<List<Map<String, dynamic>>> getHubMessages(String hubId) async {
    try {
      final res = await _dio.get('/api/v1/hangouts/$hubId/messages');
      if (res.data['success'] == true && res.data['data'] is List) {
        return List<Map<String, dynamic>>.from(res.data['data']);
      }
    } catch (_) {}
    return [];
  }

  // Send Chat Message to a Hub
  Future<Map<String, dynamic>> sendHubMessage(String hubId, String content) async {
    try {
      final res = await _dio.post('/api/v1/hangouts/$hubId/messages', data: {
        'content': content,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Direct 1-on-1 Messages APIs
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final res = await _dio.get('/api/v1/messages/conversations');
      if (res.data['success'] == true && res.data['data'] is List) {
        return List<Map<String, dynamic>>.from(res.data['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDirectChat(String peerNumber) async {
    try {
      final res = await _dio.get('/api/v1/messages/chat/$peerNumber');
      if (res.data != null) {
        if (res.data['data'] != null && res.data['data']['messages'] is List) {
          return List<Map<String, dynamic>>.from(res.data['data']['messages']);
        } else if (res.data['messages'] is List) {
          return List<Map<String, dynamic>>.from(res.data['messages']);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendDirectMessage(String peerNumber, String content) async {
    try {
      final res = await _dio.post('/api/v1/messages/chat/$peerNumber', data: {
        'content': content,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteConversation(String peerNumber) async {
    try {
      final res = await _dio.delete('/api/v1/messages/chat/$peerNumber');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Call History APIs
  Future<List<Map<String, dynamic>>> getCallHistory() async {
    try {
      final res = await _dio.get('/api/v1/calls/history');
      if (res.data['success'] == true && res.data['data'] is List) {
        return List<Map<String, dynamic>>.from(res.data['data']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> clearCallHistory() async {
    try {
      final res = await _dio.delete('/api/v1/calls/history');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCallLog(String callId) async {
    try {
      final res = await _dio.delete('/api/v1/calls/history/$callId');
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> deleteDirectMessage(String msgId) async {
    try {
      final res = await _dio.delete('/api/v1/messages/msg/$msgId');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Persistent Contacts management
  Future<List<Map<String, dynamic>>> getSavedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('saved_contacts_list') ?? [];
    if (raw.isEmpty) {
      // Return default starter contacts
      return [
        {'name': 'Zim Official (Admin)', 'number': '+1-1111111', 'district': 'Dhaka (+1)'},
        {'name': 'Tasnia', 'number': '+25-7871466', 'district': 'Rajshahi (+25)'},
        {'name': 'Rafiq Ahmed', 'number': '+1-6860499', 'district': 'Dhaka (+1)'},
        {'name': 'Farhan Ahmed', 'number': '+2-1000001', 'district': 'Narsingdi (+2)'},
        {'name': 'Kazi Sakib', 'number': '+3-9182746', 'district': 'Brahmanbaria (+3)'},
      ];
    }
    final list = raw.map((item) {
      final parts = item.split('|');
      return {
        'name': parts.isNotEmpty ? parts[0] : 'User',
        'number': parts.length > 1 ? parts[1] : '',
        'district': parts.length > 2 ? parts[2] : 'IntraCom',
      };
    }).toList();

    // Ensure Tasnia is always present
    if (!list.any((c) => (c['number'] ?? '').toString().contains('7871466'))) {
      list.insert(0, {
        'name': 'Tasnia',
        'number': '+25-7871466',
        'district': 'Rajshahi (+25)',
      });
    }

    return list;
  }

  Future<void> addContact({required String name, required String number, String district = 'IntraCom'}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('saved_contacts_list') ?? [];
    // Avoid duplicate numbers
    final exists = current.any((element) => element.contains('|$number|') || element.endsWith('|$number'));
    if (!exists) {
      current.add('$name|$number|$district');
      await prefs.setStringList('saved_contacts_list', current);
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
