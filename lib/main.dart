import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000/api',
);

const Color kBg = Color(0xFF030712);
const Color kPanel = Color(0xFF0F172A);
const Color kCard = Color(0xBF111827);
const Color kLine = Color(0x1AFFFFFF);
const Color kText = Color(0xFFF8FAFC);
const Color kMuted = Color(0xFF94A3B8);
const Color kPrimary = Color(0xFF6366F1);
const Color kPrimary2 = Color(0xFF8B5CF6);
const Color kAccent = Color(0xFF22C55E);
const Color kWarn = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

void main() {
  runApp(const StudyMateApp());
}

class StudyMateApp extends StatefulWidget {
  const StudyMateApp({super.key});

  @override
  State<StudyMateApp> createState() => _StudyMateAppState();
}

class _StudyMateAppState extends State<StudyMateApp> {
  final AppController controller = AppController(ApiClient(kApiBaseUrl));

  @override
  void initState() {
    super.initState();
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          title: 'StudyMate Mobile',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: kBg,
            colorScheme: const ColorScheme.dark(
              primary: kPrimary,
              secondary: kPrimary2,
              surface: kPanel,
              error: kDanger,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: kText,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0x9910172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kPrimary),
              ),
            ),
          ),
          home: controller.initialized
              ? (controller.isLoggedIn
                  ? HomeScreen(controller: controller)
                  : AuthScreen(controller: controller))
              : const SplashScreen(),
        );
      },
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl) : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  final String baseUrl;
  String? token;

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');
    final filtered = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.trim().isNotEmpty) filtered[entry.key] = value;
    }
    return uri.replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Map<String, String> _headers({bool jsonBody = true}) => {
        'Accept': 'application/json',
        if (jsonBody) 'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, [Map<String, String?> query = const {}]) async {
    final response = await http.get(_uri(path, query), headers: _headers());
    return _parse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(_uri(path), headers: _headers(), body: jsonEncode(body));
    return _parse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(_uri(path), headers: _headers(), body: jsonEncode(body));
    return _parse(response);
  }

  Future<dynamic> delete(String path, [Map<String, String?> query = const {}]) async {
    final response = await http.delete(_uri(path, query), headers: _headers());
    return _parse(response);
  }

  Future<dynamic> uploadFile(String path, String fieldName, XFile file) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_headers(jsonBody: false));
    final length = await file.length();
    request.files.add(http.MultipartFile(fieldName, file.openRead(), length, filename: file.name));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _parse(response);
  }

  dynamic _parse(http.Response response) {
    if (response.statusCode == 204) return null;
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = {'message': response.body};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(data, response.statusCode);
      throw ApiException(message, response.statusCode);
    }
    return data;
  }

  String _errorMessage(dynamic data, int code) {
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['errors'] is Map) {
        final parts = <String>[];
        for (final value in (data['errors'] as Map).values) {
          if (value is List) parts.addAll(value.map((e) => e.toString()));
          if (value is String) parts.add(value);
        }
        if (parts.isNotEmpty) return parts.join('\n');
      }
    }
    return 'Terjadi kesalahan server. HTTP $code';
  }
}

class SessionStore {
  static const _tokenKey = 'studymate_token';
  static const _userKey = 'studymate_user';

  Future<({String? token, Map<String, dynamic>? user})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);
    Map<String, dynamic>? user;
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map) user = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return (token: prefs.getString(_tokenKey), user: user);
  }

  Future<void> save({required String token, required Map<String, dynamic> user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}

class AppController extends ChangeNotifier {
  AppController(this.api);

  final ApiClient api;
  final SessionStore store = SessionStore();

  bool initialized = false;
  bool busy = false;
  String? lastError;

  String? token;
  Map<String, dynamic>? user;
  Map<String, dynamic>? bootstrap;
  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? matches;
  Map<String, dynamic>? studyPlan;
  Map<String, dynamic>? aiHealth;
  List<dynamic> groups = [];
  List<dynamic> notifications = [];
  List<dynamic> friends = [];
  int unreadNotifications = 0;
  final List<Map<String, dynamic>> coachMessages = [
    {
      'sender': 'AI Coach',
      'message': 'Halo. Saya Study Coach-mu. Tanyakan jadwal belajar, strategi kuliah, atau cara mengatur tugas.',
      'timestamp': '',
    }
  ];

  bool get isLoggedIn => userId != null;
  String? get userId => textOrNull(user, ['id']);
  String get userName => textOf(user, ['name'], fallback: 'Pengguna');
  String get userEmail => textOf(user, ['email'], fallback: '');
  String get role => textOf(user, ['role'], fallback: 'student');

  Future<void> init() async {
    final session = await store.load();
    token = session.token;
    user = session.user;
    api.token = token;
    initialized = true;
    notifyListeners();
    if (isLoggedIn) {
      await bootstrapApp(silent: true);
      await refreshHome(silent: true);
    } else {
      await loadBootstrap(silent: true);
    }
  }

  Future<T?> _run<T>(Future<T> Function() task, {bool silent = false}) async {
    if (!silent) {
      busy = true;
      lastError = null;
      notifyListeners();
    }
    try {
      return await task();
    } catch (e) {
      lastError = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    } finally {
      if (!silent) {
        busy = false;
      }
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final result = await _run(() async {
      final data = await api.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final map = asMap(data);
      token = textOf(map, ['token'], fallback: '');
      user = asMap(map['user']);
      api.token = token;
      if (token == null || token!.isEmpty || user == null || userId == null) {
        throw ApiException('Respons login tidak lengkap.');
      }
      await store.save(token: token!, user: user!);
      await bootstrapApp(silent: true);
      await refreshHome(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String university,
    required String programName,
    required String studentId,
    required int semester,
    required String password,
    required String confirmPassword,
  }) async {
    final result = await _run(() async {
      await api.post('/auth/register', {
        'name': name.trim().toUpperCase(),
        'email': email.trim(),
        'university': university.trim().toUpperCase(),
        'programName': programName.trim().toUpperCase(),
        'semester': semester,
        'password': password,
        'password_confirmation': confirmPassword,
        'studentId': studentId.trim().toUpperCase(),
      });
      return true;
    });
    return result == true;
  }

  Future<void> logout() async {
    token = null;
    user = null;
    dashboard = null;
    matches = null;
    studyPlan = null;
    groups = [];
    notifications = [];
    friends = [];
    unreadNotifications = 0;
    api.token = null;
    await store.clear();
    notifyListeners();
  }

  Future<void> bootstrapApp({bool silent = false}) async {
    await loadBootstrap(silent: silent);
  }

  Future<void> loadBootstrap({bool silent = false}) async {
    await _run(() async {
      bootstrap = asMap(await api.get('/bootstrap'));
    }, silent: silent);
  }

  Future<void> refreshHome({bool silent = false}) async {
    if (!isLoggedIn) return;
    await Future.wait([
      loadDashboard(silent: silent),
      loadGroups(silent: silent),
      loadMatches(silent: silent),
      loadNotifications(silent: silent),
      loadStudyPlan(silent: true),
      loadFriends(silent: true),
    ]);
  }

  Future<void> loadDashboard({bool silent = false}) async {
    if (!isLoggedIn) return;
    await _run(() async {
      dashboard = asMap(await api.get('/dashboard/$userId'));
      final dashboardUser = asMapOrNull(dashboard?['user']);
      if (dashboardUser != null) {
        user = {...?user, ...dashboardUser};
        if (token != null) await store.save(token: token!, user: user!);
      }
    }, silent: silent);
  }

  Future<void> loadProfile({bool silent = false}) async {
    if (!isLoggedIn) return;
    await _run(() async {
      user = asMap(await api.get('/users/$userId'));
      if (token != null) await store.save(token: token!, user: user!);
    }, silent: silent);
  }

  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    final result = await _run(() async {
      final cleaned = Map<String, dynamic>.from(payload)..removeWhere((_, value) => value == null);
      user = asMap(await api.put('/users/$userId', cleaned));
      if (token != null) await store.save(token: token!, user: user!);
      await loadDashboard(silent: true);
      studyPlan = null;
      await loadStudyPlan(force: true, silent: true);
      await loadMatches(silent: true);
      return true;
    });
    return result == true;
  }

  Future<void> loadGroups({String search = '', String courseId = '', bool silent = false}) async {
    await _run(() async {
      final data = await api.get('/groups', {
        'search': search,
        'courseId': courseId,
      });
      groups = asList(data);
    }, silent: silent);
  }

  Future<bool> createGroup(Map<String, dynamic> payload) async {
    final result = await _run(() async {
      await api.post('/groups', {...payload, 'ownerId': userId});
      await loadGroups(silent: true);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> updateGroup(String groupId, Map<String, dynamic> payload) async {
    final result = await _run(() async {
      await api.put('/groups/$groupId', {...payload, 'actorId': userId, 'actorName': userName});
      await loadGroups(silent: true);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> deleteGroup(String groupId) async {
    final result = await _run(() async {
      await api.delete('/groups/$groupId', {'actorId': userId});
      await loadGroups(silent: true);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> uploadAvatar(XFile file) async {
    final result = await _run(() async {
      user = asMap(await api.uploadFile('/users/$userId/avatar', 'avatar', file));
      if (token != null) await store.save(token: token!, user: user!);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> uploadKtm(XFile file) async {
    final result = await _run(() async {
      final data = asMap(await api.uploadFile('/users/$userId/ktm', 'ktm', file));
      final updatedUser = asMapOrNull(data['user']) ?? data;
      if (updatedUser.isNotEmpty) {
        user = updatedUser;
        if (token != null) await store.save(token: token!, user: user!);
      }
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> joinGroup(String groupId) async {
    final result = await _run(() async {
      await api.post('/groups/$groupId/join', {'userId': userId});
      await loadGroups(silent: true);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> leaveGroup(String groupId) async {
    final result = await _run(() async {
      await api.post('/groups/$groupId/leave', {'userId': userId});
      await loadGroups(silent: true);
      await loadDashboard(silent: true);
      return true;
    });
    return result == true;
  }

  Future<List<dynamic>> loadGroupMessages(String groupId) async {
    final data = await api.get('/groups/$groupId/messages', {'userId': userId});
    return asList(data);
  }

  Future<Map<String, dynamic>?> sendGroupMessage(String groupId, String message) async {
    final data = await api.post('/groups/$groupId/messages', {'userId': userId, 'message': message.trim()});
    return asMapOrNull(data);
  }

  Future<Map<String, dynamic>?> getGoldenHour(String groupId) async {
    final data = await _run(() async => asMap(await api.get('/groups/$groupId/golden-hour')));
    return data;
  }

  Future<Map<String, dynamic>?> getGroupSummary(String groupId, {bool force = false}) async {
    try {
      return asMap(await api.get('/groups/$groupId/summary', {
        'userId': userId,
        if (force) 'force': '1',
      }));
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadMatches({String search = '', bool silent = false}) async {
    if (!isLoggedIn) return;
    await _run(() async {
      matches = asMap(await api.get('/matchmaking/$userId', {'search': search}));
    }, silent: silent);
  }

  Future<bool> sendStudyInvite(Map<String, dynamic> targetUser) async {
    final receiverId = textOrNull(targetUser, ['id', '_id']);
    if (receiverId == null) {
      lastError = 'ID pengguna tujuan tidak ditemukan.';
      notifyListeners();
      return false;
    }
    final result = await _run(() async {
      await api.post('/notifications', {
        'senderId': userId,
        'receiverId': receiverId,
        'type': 'study_invite',
        'message': '$userName mengajakmu untuk belajar bersama!',
        'data': {
          'senderName': userName,
          'senderProgram': textOf(user, ['program_name', 'programName'], fallback: ''),
          'status': 'pending',
        },
      });
      return true;
    });
    return result == true;
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!isLoggedIn) return;
    await _run(() async {
      final data = asMap(await api.get('/notifications/$userId'));
      notifications = asList(data['notifications']);
      unreadNotifications = intOf(data, ['unreadCount']);
    }, silent: silent);
  }

  Future<bool> markNotificationRead(String id) async {
    if (id.trim().isEmpty) {
      lastError = 'ID notifikasi tidak ditemukan.';
      notifyListeners();
      return false;
    }
    final result = await _run(() async {
      await api.put('/notifications/$id/read', {});
      await loadNotifications(silent: true);
      return true;
    }, silent: true);
    return result == true;
  }

  Future<bool> markAllNotificationsRead() async {
    if (!isLoggedIn) return false;
    final result = await _run(() async {
      await api.put('/notifications/$userId/read-all', {});
      await loadNotifications(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> acceptInvite(String id) async {
    if (id.trim().isEmpty) {
      lastError = 'ID undangan tidak ditemukan.';
      notifyListeners();
      return false;
    }
    final result = await _run(() async {
      await api.post('/notifications/$id/accept', {});
      await loadNotifications(silent: true);
      await loadFriends(silent: true);
      await loadDashboard(silent: true);
      await loadMatches(silent: true);
      return true;
    });
    return result == true;
  }

  Future<bool> rejectInvite(String id) async {
    if (id.trim().isEmpty) {
      lastError = 'ID undangan tidak ditemukan.';
      notifyListeners();
      return false;
    }
    final result = await _run(() async {
      await api.post('/notifications/$id/reject', {});
      await loadNotifications(silent: true);
      return true;
    });
    return result == true;
  }

  Future<void> loadFriends({bool silent = false}) async {
    if (!isLoggedIn) return;
    await _run(() async {
      friends = asList(await api.get('/users/$userId/friends'));
    }, silent: silent);
  }

  Future<List<dynamic>> getPrivateMessages(String friendId) async {
    return asList(await api.get('/chat/$userId/$friendId'));
  }

  Future<void> sendPrivateMessage(String friendId, String message) async {
    await api.post('/chat/send', {
      'sender_id': userId,
      'receiver_id': friendId,
      'message': message.trim(),
    });
  }

  Future<void> loadStudyPlan({bool force = false, bool silent = false}) async {
    if (!isLoggedIn) return;
    if (!force && studyPlan != null) return;
    await _run(() async {
      studyPlan = asMap(await api.get('/users/$userId/study-plan'));
    }, silent: silent);
  }

  Future<void> loadAiHealth() async {
    await _run(() async {
      aiHealth = asMap(await api.get('/ai/health'));
    }, silent: true);
  }

  Future<bool> askCoach(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || !isLoggedIn) return false;
    coachMessages.add({'sender': 'Me', 'message': trimmed, 'timestamp': DateTime.now().toIso8601String()});
    notifyListeners();
    final result = await _run(() async {
      final history = coachMessages
          .where((m) => m['message'] != null)
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => {
                'role': m['sender'] == 'Me' ? 'user' : 'assistant',
                'content': m['message'],
              })
          .toList();
      final data = asMap(await api.post('/users/$userId/coach', {'message': trimmed, 'history': history}));
      coachMessages.add(data);
      return true;
    });
    return result == true;
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, val) => MapEntry(key.toString(), val));
  return <String, dynamic>{};
}

Map<String, dynamic>? asMapOrNull(dynamic value) {
  if (value == null) return null;
  final map = asMap(value);
  return map.isEmpty ? null : map;
}

List<dynamic> asList(dynamic value) => value is List ? value : <dynamic>[];

String textOf(dynamic source, List<String> keys, {String fallback = '-'}) {
  return textOrNull(source, keys) ?? fallback;
}

String? textOrNull(dynamic source, List<String> keys) {
  final map = asMapOrNull(source);
  if (map == null) return null;
  for (final key in keys) {
    final value = map[key];
    if (value != null && value.toString().trim().isNotEmpty) return value.toString();
  }
  return null;
}

int intOf(dynamic source, List<String> keys, {int fallback = 0}) {
  final map = asMapOrNull(source);
  if (map == null) return fallback;
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool boolOf(dynamic source, List<String> keys, {bool fallback = false}) {
  final map = asMapOrNull(source);
  if (map == null) return fallback;
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return ['true', '1', 'yes'].contains(value.toLowerCase());
  }
  return fallback;
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'SM';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}


String notificationTypeLabel(String type) {
  switch (type) {
    case 'study_invite':
      return 'Undangan Belajar';
    case 'group_activity':
      return 'Aktivitas Grup';
    case 'group_join':
      return 'Anggota Baru Grup';
    case 'private_message':
      return 'Pesan Pribadi';
    case 'invite_accepted':
      return 'Undangan Diterima';
    default:
      return type
          .split('_')
          .where((part) => part.trim().isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
          .join(' ');
  }
}

String notificationStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Menunggu';
    case 'accepted':
      return 'Diterima';
    case 'rejected':
      return 'Ditolak';
    default:
      return status
          .split('_')
          .where((part) => part.trim().isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
          .join(' ');
  }
}

Color notificationStatusColor(String status) {
  switch (status) {
    case 'accepted':
      return kAccent;
    case 'rejected':
      return kDanger;
    case 'pending':
      return kWarn;
    default:
      return kPrimary;
  }
}

Color colorFromSeed(String seed) {
  final colors = [kPrimary, kPrimary2, kAccent, const Color(0xFF06B6D4), const Color(0xFFF97316), const Color(0xFFEC4899)];
  return colors[seed.hashCode.abs() % colors.length];
}

void showSnack(BuildContext context, String? message, {bool error = false}) {
  final text = message?.trim();
  if (text == null || text.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? kDanger : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child, this.appBar, this.bottomNavigationBar, this.floatingActionButton});
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: kBg),
        Positioned(
          top: -250,
          left: -220,
          child: _Glow(size: 560, color: kPrimary.withOpacity(0.22)),
        ),
        Positioned(
          bottom: -320,
          right: -260,
          child: _Glow(size: 640, color: kPrimary2.withOpacity(0.18)),
        ),
        Positioned(
          top: 120,
          right: -260,
          child: _Glow(size: 420, color: kAccent.withOpacity(0.08)),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              border: Border.all(color: kLine),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon ?? Icons.arrow_forward_rounded),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kMuted)),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.name, this.size = 44, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? colorFromSeed(name),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: (color ?? colorFromSeed(name)).withOpacity(0.35), blurRadius: 18)],
      ),
      child: Center(
        child: Text(initials(name), style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.34, color: Colors.white)),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (color ?? kPrimary).withOpacity(0.12),
        border: Border.all(color: (color ?? kPrimary).withOpacity(0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color ?? kPrimary), const SizedBox(width: 6)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final regEmail = TextEditingController();
  final university = TextEditingController(text: 'UNIVERSITAS INDONESIA');
  final programName = TextEditingController();
  int regSemester = 1;
  final studentId = TextEditingController();
  final regPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    regEmail.dispose();
    university.dispose();
    programName.dispose();
    studentId.dispose();
    regPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> doLogin() async {
    FocusScope.of(context).unfocus();
    final ok = await widget.controller.login(email: email.text, password: password.text);
    if (!mounted) return;
    showSnack(context, ok ? 'Login berhasil.' : widget.controller.lastError, error: !ok);
  }

  Future<void> doRegister() async {
    FocusScope.of(context).unfocus();
    final sem = regSemester;
    final ok = await widget.controller.register(
      name: name.text,
      email: regEmail.text,
      university: university.text,
      programName: programName.text,
      studentId: studentId.text,
      semester: sem,
      password: regPassword.text,
      confirmPassword: confirmPassword.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => isLogin = true);
      showSnack(context, 'Registrasi berhasil. Silakan login.');
    } else {
      showSnack(context, widget.controller.lastError, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(18),
            shrinkWrap: true,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AvatarBadge(name: 'StudyMate', size: 52, color: kPrimary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('StudyMate', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                              Text('Mobile app untuk kolaborasi belajar.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Masuk'), icon: Icon(Icons.login_rounded)),
                        ButtonSegment(value: false, label: Text('Daftar'), icon: Icon(Icons.person_add_alt_1_rounded)),
                      ],
                      selected: {isLogin},
                      onSelectionChanged: (value) => setState(() => isLogin = value.first),
                    ),
                    const SizedBox(height: 18),
                    if (isLogin) ...[
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) => doLogin()),
                      const SizedBox(height: 16),
                      PrimaryButton(label: 'Masuk', icon: Icons.arrow_forward_rounded, loading: widget.controller.busy, onPressed: doLogin),
                    ] else ...[
                      TextField(
                        controller: name,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: const [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(labelText: 'Nama lengkap'),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: regEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: studentId,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: const [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(labelText: 'NIM / Student ID'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: university,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: const [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(labelText: 'Universitas'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: programName,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: const [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(labelText: 'Program Studi'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: regSemester,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        items: List.generate(8, (index) => index + 1)
                            .map((value) => DropdownMenuItem(value: value, child: Text('Semester $value')))
                            .toList(),
                        onChanged: (value) => setState(() => regSemester = value ?? 1),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: regPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Password minimal 6 karakter')),
                      const SizedBox(height: 12),
                      TextField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi password'), onSubmitted: (_) => doRegister()),
                      const SizedBox(height: 16),
                      PrimaryButton(label: 'Buat akun', icon: Icons.person_add_alt_1_rounded, loading: widget.controller.busy, onPressed: doRegister),
                    ],
                    const SizedBox(height: 14),
                    Text('API: $kApiBaseUrl', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.controller.refreshHome(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Dashboard', 'Grup Belajar', 'Smart Match', 'AI Coach', 'Profil'];
    return AppScaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Notifikasi',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsScreen(controller: widget.controller))),
                icon: const Icon(Icons.notifications_rounded),
              ),
              if (widget.controller.unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: kDanger, borderRadius: BorderRadius.circular(999)),
                    child: Text('${widget.controller.unreadNotifications}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.controller.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: kPanel,
        indicatorColor: kPrimary.withOpacity(0.25),
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
          if (value == 0) widget.controller.loadDashboard(silent: true);
          if (value == 1) widget.controller.loadGroups(silent: true);
          if (value == 2) widget.controller.loadMatches(silent: true);
          if (value == 3) widget.controller.loadStudyPlan(silent: true);
          if (value == 4) widget.controller.loadProfile(silent: true);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Grup'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'Match'),
          NavigationDestination(icon: Icon(Icons.psychology_rounded), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
      child: IndexedStack(
        index: index,
        children: [
          DashboardTab(controller: widget.controller),
          GroupsTab(controller: widget.controller),
          MatchmakingTab(controller: widget.controller),
          AiCoachTab(controller: widget.controller),
          ProfileTab(controller: widget.controller),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final stats = asMap(controller.dashboard?['stats']);
    final upcoming = asList(controller.dashboard?['upcomingGroups']);
    final recommendations = asList(controller.dashboard?['recommendations']);
    final activities = asList(controller.dashboard?['recentActivities']);
    return RefreshIndicator(
      onRefresh: () => controller.refreshHome(),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        children: [
          if (controller.lastError != null) ErrorBanner(message: controller.lastError!),
          GlassCard(
            child: Row(
              children: [
                AvatarBadge(name: controller.userName, size: 54, color: colorFromSeed(controller.userId ?? controller.userName)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(controller.userName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(controller.userEmail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kMuted)),
                      const SizedBox(height: 9),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Pill(textOf(controller.user, ['program_name', 'programName'], fallback: 'Program belum diisi'), icon: Icons.school_rounded),
                        Pill('Semester ${textOf(controller.user, ['semester'], fallback: '-')}', icon: Icons.calendar_month_rounded, color: kAccent),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Ringkasan Belajar', subtitle: 'Data diambil dari dashboard Laravel.'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 620;
              return GridView.count(
                crossAxisCount: wide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: wide ? 1.55 : 1.3,
                children: [
                  StatCard(label: 'Grup Diikuti', value: intOf(stats, ['joinedGroups']).toString(), icon: Icons.groups_rounded, color: kPrimary),
                  StatCard(label: 'Grup Dibuat', value: intOf(stats, ['createdGroups']).toString(), icon: Icons.add_circle_rounded, color: kPrimary2),
                  StatCard(label: 'Mata Kuliah', value: intOf(stats, ['selectedCourses']).toString(), icon: Icons.menu_book_rounded, color: kAccent),
                  StatCard(label: 'Match Signal', value: '${intOf(stats, ['compatibilitySignal'])}%', icon: Icons.bolt_rounded, color: kWarn),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SectionTitle(
            'Rekomendasi Jadwal Belajar',
            subtitle: 'Berdasarkan mata kuliah dan availability yang tersimpan di profil.',
            action: IconButton(
              onPressed: () => controller.loadStudyPlan(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 10),
          StudyScheduleCard(plan: controller.studyPlan),
          const SizedBox(height: 18),
          const SectionTitle('Grup Terdekat'),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const EmptyCard(icon: Icons.groups_2_rounded, title: 'Belum ada grup aktif', subtitle: 'Buat atau bergabung ke grup belajar terlebih dahulu.')
          else
            ...upcoming.take(4).map((g) => GroupCard(controller: controller, group: asMap(g), compact: true)),
          const SizedBox(height: 18),
          const SectionTitle('Rekomendasi Partner'),
          const SizedBox(height: 10),
          if (recommendations.isEmpty)
            const EmptyCard(icon: Icons.auto_awesome_rounded, title: 'Belum ada rekomendasi', subtitle: 'Lengkapi profil, mata kuliah, dan jadwal belajar.')
          else
            ...recommendations.take(3).map((m) => MatchCard(controller: controller, match: asMap(m), compact: true)),
          const SizedBox(height: 18),
          const SectionTitle('Aktivitas Terbaru'),
          const SizedBox(height: 10),
          if (activities.isEmpty)
            const EmptyCard(icon: Icons.history_rounded, title: 'Belum ada aktivitas', subtitle: 'Aktivitas akun akan muncul di sini.')
          else
            ...activities.take(5).map((a) {
              final item = asMap(a);
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: kMuted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(textOf(item, ['message'], fallback: '-'))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class StudyScheduleCard extends StatelessWidget {
  const StudyScheduleCard({super.key, required this.plan});
  final Map<String, dynamic>? plan;

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const EmptyCard(
        icon: Icons.event_available_rounded,
        title: 'Jadwal belajar belum dimuat',
        subtitle: 'Tarik ke bawah atau tekan refresh untuk memuat rekomendasi jadwal belajar.',
      );
    }

    final sessions = asList(plan?['sessions']);
    final tips = asList(plan?['tips']);
    final focusWindow = textOrNull(plan, ['recommendedFocusWindow']);
    final headline = textOf(plan, ['headline'], fallback: 'Rekomendasi jadwal belajar');
    final summary = textOf(plan, ['summary'], fallback: 'Lengkapi mata kuliah dan availability di profil agar jadwal lebih presisi.');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule_rounded, color: kPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(summary, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (focusWindow != null) ...[
            const SizedBox(height: 12),
            Pill('Fokus utama: $focusWindow', icon: Icons.bolt_rounded, color: kWarn),
          ],
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            const EmptyCard(
              icon: Icons.menu_book_rounded,
              title: 'Belum ada sesi belajar',
              subtitle: 'Buka Profil, isi mata kuliah aktif, lalu tambahkan availability dengan format: SENIN 19:00.',
            )
          else
            ...sessions.take(4).map((session) => StudySessionTile(session: asMap(session))),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tips', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ...tips.take(2).map((tip) => BulletText(tip.toString())),
          ],
        ],
      ),
    );
  }
}

class StudySessionTile extends StatelessWidget {
  const StudySessionTile({super.key, required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final courseCode = textOf(session, ['courseCode'], fallback: '');
    final courseName = textOf(session, ['courseName'], fallback: 'Mata kuliah');
    final slot = textOf(session, ['slot'], fallback: '${textOf(session, ['day'], fallback: '')} ${textOf(session, ['time'], fallback: '')}'.trim());
    final duration = intOf(session, ['durationMinutes'], fallback: 90);
    final focus = textOf(session, ['focus'], fallback: 'Review materi dan latihan soal.');
    final title = [courseCode, courseName].where((e) => e.trim().isNotEmpty).join(' — ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x6610172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book_rounded, color: kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isEmpty ? 'Mata kuliah' : title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('$slot · $duration menit', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                const SizedBox(height: 4),
                Text(focus, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kDanger),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Icon(icon, color: kMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key, required this.controller});
  final AppController controller;

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  final search = TextEditingController();
  String courseId = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> reload() => widget.controller.loadGroups(search: search.text, courseId: courseId);

  @override
  Widget build(BuildContext context) {
    final courses = asList(widget.controller.bootstrap?['courses']);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
        children: [
          SectionTitle(
            'Grup Belajar',
            subtitle: 'Cari, buat, join, leave, dan chat grup.',
            action: IconButton.filled(
              onPressed: () async {
                final created = await showDialog<bool>(context: context, builder: (_) => CreateGroupDialog(controller: widget.controller));
                if (created == true && mounted) showSnack(context, 'Grup berhasil dibuat.');
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Cari nama/topik/deskripsi grup'),
                  onSubmitted: (_) => reload(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: courseId.isEmpty ? null : courseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Filter mata kuliah'),
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('Semua mata kuliah')),
                    ...courses.map((c) {
                      final course = asMap(c);
                      final id = textOf(course, ['id'], fallback: '');
                      final label = '${textOf(course, ['code'], fallback: '')} ${textOf(course, ['name'], fallback: '')}'.trim();
                      return DropdownMenuItem<String>(value: id, child: Text(label.isEmpty ? id : label));
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => courseId = value ?? '');
                    reload();
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(label: 'Terapkan filter', icon: Icons.tune_rounded, loading: widget.controller.busy, onPressed: reload),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.controller.groups.isEmpty)
            const EmptyCard(icon: Icons.groups_rounded, title: 'Grup belum ditemukan', subtitle: 'Coba ubah filter atau buat grup baru.')
          else
            ...widget.controller.groups.map((g) => GroupCard(controller: widget.controller, group: asMap(g))),
        ],
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.controller, required this.group, this.compact = false});
  final AppController controller;
  final Map<String, dynamic> group;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final members = asList(group['members']);
    final course = asMap(group['course']);
    final location = asMap(group['location']);
    final groupId = textOf(group, ['id'], fallback: '');
    final ownerId = textOf(group, ['owner_id', 'ownerId'], fallback: '');
    final isOwner = ownerId == controller.userId;
    final isMember = members.any((m) => textOf(m, ['id'], fallback: '') == controller.userId) || isOwner;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(textOf(group, ['title'], fallback: 'Grup Belajar'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(textOf(group, ['topic'], fallback: '-'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kMuted)),
                  ],
                ),
              ),
              if (isOwner) const Pill('Owner', icon: Icons.verified_rounded, color: kAccent),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(textOf(course, ['code', 'name'], fallback: 'Mata kuliah'), icon: Icons.menu_book_rounded),
              Pill(textOf(location, ['name'], fallback: 'Lokasi'), icon: Icons.place_rounded, color: kPrimary2),
              Pill(textOf(group, ['schedule'], fallback: 'Jadwal'), icon: Icons.schedule_rounded, color: kWarn),
              Pill('${members.length}/${intOf(group, ['capacity'])} anggota', icon: Icons.people_alt_rounded, color: kAccent),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(textOf(group, ['description'], fallback: 'Tidak ada deskripsi.'), style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(controller: controller, group: group))),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Detail'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isOwner ? null : () async {
                    final ok = isMember ? await controller.leaveGroup(groupId) : await controller.joinGroup(groupId);
                    if (context.mounted) showSnack(context, ok ? (isMember ? 'Berhasil keluar dari grup.' : 'Berhasil join grup.') : controller.lastError, error: !ok);
                  },
                  icon: Icon(isMember ? Icons.logout_rounded : Icons.group_add_rounded),
                  label: Text(isOwner ? 'Owner' : (isMember ? 'Leave' : 'Join')),
                ),
              ),
            ],
          ),
          if (isOwner && !compact) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(context: context, builder: (_) => CreateGroupDialog(controller: controller, group: group));
                      if (context.mounted && ok == true) showSnack(context, 'Grup berhasil diperbarui.');
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Hapus grup?'),
                          content: Text('Grup ${textOf(group, ['title'], fallback: '')} akan dihapus permanen.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      final ok = await controller.deleteGroup(groupId);
                      if (context.mounted) showSnack(context, ok ? 'Grup berhasil dihapus.' : controller.lastError, error: !ok);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key, required this.controller, this.group});
  final AppController controller;
  final Map<String, dynamic>? group;

  bool get isEdit => group != null;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final title = TextEditingController();
  final topic = TextEditingController();
  final description = TextEditingController();
  final schedule = TextEditingController();
  final capacity = TextEditingController(text: '5');
  final courseName = TextEditingController();
  final locationName = TextEditingController();

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    if (group != null) {
      title.text = textOf(group, ['title'], fallback: '');
      topic.text = textOf(group, ['topic'], fallback: '');
      description.text = textOf(group, ['description'], fallback: '');
      schedule.text = textOf(group, ['schedule'], fallback: '');
      capacity.text = intOf(group, ['capacity'], fallback: 5).toString();
      final course = asMap(group['course']);
      final location = asMap(group['location']);
      courseName.text = textOf(course, ['name', 'code'], fallback: '');
      locationName.text = textOf(location, ['name'], fallback: '');
    }
  }

  @override
  void dispose() {
    title.dispose();
    topic.dispose();
    description.dispose();
    schedule.dispose();
    capacity.dispose();
    courseName.dispose();
    locationName.dispose();
    super.dispose();
  }

  bool get isValid => title.text.trim().isNotEmpty &&
      topic.text.trim().isNotEmpty &&
      schedule.text.trim().isNotEmpty &&
      courseName.text.trim().isNotEmpty &&
      locationName.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Grup Belajar' : 'Buat Grup Belajar'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Nama grup'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topic,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Topik'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: schedule,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Jadwal, contoh: JUMAT 19:00'),
              ),
              const SizedBox(height: 10),
              TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kapasitas')),
              const SizedBox(height: 10),
              TextField(
                controller: courseName,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Mata kuliah'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationName,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UpperCaseTextFormatter()],
                decoration: const InputDecoration(labelText: 'Lokasi'),
              ),
              const SizedBox(height: 10),
              Text(
                'Form grup mengikuti revisi: tidak memakai dropdown master data, hanya input manual. Backend tetap akan membuat/menautkan course dan lokasi otomatis.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: () async {
            final payload = {
              'title': title.text.trim(),
              'topic': topic.text.trim(),
              'description': description.text.trim(),
              'schedule': schedule.text.trim(),
              'capacity': int.tryParse(capacity.text) ?? 5,
              'courseName': courseName.text.trim(),
              'locationName': locationName.text.trim(),
            };
            final ok = widget.isEdit
                ? await widget.controller.updateGroup(textOf(widget.group, ['id'], fallback: ''), payload)
                : await widget.controller.createGroup(payload);
            if (!context.mounted) return;
            if (ok) {
              Navigator.pop(context, true);
            } else {
              showSnack(context, widget.controller.lastError, error: true);
            }
          },
          child: Text(widget.isEdit ? 'Simpan' : 'Buat'),
        ),
      ],
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.controller, required this.group});
  final AppController controller;
  final Map<String, dynamic> group;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<dynamic> messages = [];
  Map<String, dynamic>? goldenHour;
  Map<String, dynamic>? summary;
  bool loadingMessages = false;
  final message = TextEditingController();

  String get groupId => textOf(widget.group, ['id'], fallback: '');

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    setState(() => loadingMessages = true);
    try {
      messages = await widget.controller.loadGroupMessages(groupId);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loadingMessages = false);
    }
  }

  Future<void> send() async {
    if (message.text.trim().isEmpty) return;
    try {
      final sent = await widget.controller.sendGroupMessage(groupId, message.text);
      message.clear();
      if (sent != null) messages = [...messages, sent];
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final members = asList(group['members']);
    return AppScaffold(
      appBar: AppBar(title: Text(textOf(group, ['title'], fallback: 'Detail Grup'))),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textOf(group, ['title'], fallback: 'Grup'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(textOf(group, ['description'], fallback: 'Tidak ada deskripsi.'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kMuted)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Pill(textOf(asMap(group['course']), ['name', 'code'], fallback: 'Mata kuliah'), icon: Icons.menu_book_rounded),
                  Pill(textOf(asMap(group['location']), ['name'], fallback: 'Lokasi'), icon: Icons.place_rounded),
                  Pill(textOf(group, ['schedule'], fallback: 'Jadwal'), icon: Icons.schedule_rounded),
                  Pill('${members.length}/${intOf(group, ['capacity'])} anggota', icon: Icons.people_alt_rounded),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    goldenHour = await widget.controller.getGoldenHour(groupId);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Golden Hour'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    summary = await widget.controller.getGroupSummary(groupId);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.summarize_rounded),
                  label: const Text('Ringkasan AI'),
                ),
              ),
            ],
          ),
          if (goldenHour != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Golden Hour', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(textOf(goldenHour, ['headline'], fallback: '-')),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Pill(textOf(goldenHour, ['bestSlot'], fallback: 'Belum ada slot'), icon: Icons.access_time_rounded, color: kAccent),
                    Pill('${intOf(goldenHour, ['coverage'])}% coverage', icon: Icons.percent_rounded, color: kWarn),
                  ]),
                ],
              ),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan Diskusi', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(textOf(summary, ['summary', 'message'], fallback: jsonEncode(summary))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Anggota'),
          const SizedBox(height: 10),
          GlassCard(
            child: members.isEmpty
                ? const Text('Belum ada data anggota.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((m) => Pill(textOf(m, ['name'], fallback: 'Anggota'), icon: Icons.person_rounded)).toList(),
                  ),
          ),
          const SizedBox(height: 18),
          SectionTitle('Chat Grup', action: IconButton(onPressed: loadMessages, icon: const Icon(Icons.refresh_rounded))),
          const SizedBox(height: 10),
          if (loadingMessages)
            const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
          else if (messages.isEmpty)
            const EmptyCard(icon: Icons.chat_bubble_outline_rounded, title: 'Belum ada pesan', subtitle: 'Kirim pesan pertama ke grup ini.')
          else
            ...messages.map((m) => MessageBubble(message: asMap(m), currentUserId: widget.controller.userId ?? '')),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: TextField(controller: message, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Tulis pesan...', border: InputBorder.none), onSubmitted: (_) => send())),
                IconButton.filled(onPressed: send, icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.currentUserId});
  final Map<String, dynamic> message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final sender = asMap(message['user'] ?? message['sender']);
    final topSender = textOf(message, ['sender'], fallback: '');
    final senderId = textOf(sender, ['id'], fallback: textOf(message, ['sender_id', 'sender'], fallback: ''));
    final mine = senderId == currentUserId;
    final displayName = mine ? 'Saya' : textOf(sender, ['name'], fallback: topSender.isEmpty ? 'Pengguna' : topSender);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? kPrimary.withOpacity(0.35) : kPanel.withOpacity(0.9),
          border: Border.all(color: kLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 4),
            Text(textOf(message, ['message'], fallback: '')),
          ],
        ),
      ),
    );
  }
}

class MatchmakingTab extends StatefulWidget {
  const MatchmakingTab({super.key, required this.controller});
  final AppController controller;

  @override
  State<MatchmakingTab> createState() => _MatchmakingTabState();
}

class _MatchmakingTabState extends State<MatchmakingTab> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnerMatches = asList(widget.controller.matches?['partnerMatches']);
    final groupMatches = asList(widget.controller.matches?['groupMatches']);
    return RefreshIndicator(
      onRefresh: () => widget.controller.loadMatches(search: search.text),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        children: [
          SectionTitle('Smart Match', subtitle: 'Partner dan grup yang cocok berdasarkan profil akademik.'),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Cari partner'), onSubmitted: (_) => widget.controller.loadMatches(search: search.text))),
                const SizedBox(width: 10),
                IconButton.filled(onPressed: () => widget.controller.loadMatches(search: search.text), icon: const Icon(Icons.search_rounded)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Partner Rekomendasi'),
          const SizedBox(height: 10),
          if (partnerMatches.isEmpty)
            const EmptyCard(icon: Icons.auto_awesome_rounded, title: 'Belum ada match', subtitle: 'Lengkapi profil, course, dan availability.')
          else
            ...partnerMatches.map((m) => MatchCard(controller: widget.controller, match: asMap(m))),
          const SizedBox(height: 18),
          const SectionTitle('Grup Cocok'),
          const SizedBox(height: 10),
          if (groupMatches.isEmpty)
            const EmptyCard(icon: Icons.groups_rounded, title: 'Belum ada grup rekomendasi', subtitle: 'Coba tambah mata kuliah di profil.')
          else
            ...groupMatches.map((g) => GroupCard(controller: widget.controller, group: asMap(g))),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.controller, required this.match, this.compact = false});
  final AppController controller;
  final Map<String, dynamic> match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final target = asMap(match['user']);
    final reasons = asList(match['reasons']);
    final sharedCourses = asList(match['sharedCourses']);
    final name = textOf(target, ['name'], fallback: 'Partner');
    final score = intOf(match, ['score']);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBadge(name: name, color: colorFromSeed(textOf(target, ['id'], fallback: name))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text(textOf(target, ['program_name', 'programName'], fallback: 'Program tidak tersedia'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                  ],
                ),
              ),
              CircleAvatar(
                backgroundColor: kAccent.withOpacity(0.16),
                child: Text('$score', style: const TextStyle(fontWeight: FontWeight.w900, color: kAccent)),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill('${textOf(match, ['confidence'], fallback: 'Confidence')} confidence', icon: Icons.verified_rounded, color: kAccent),
                if (sharedCourses.isNotEmpty) Pill('${sharedCourses.length} course sama', icon: Icons.menu_book_rounded),
              ],
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...reasons.take(3).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [const Icon(Icons.check_circle_rounded, size: 16, color: kAccent), const SizedBox(width: 8), Expanded(child: Text(r.toString()))]),
                  )),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(controller: controller, friend: target))),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final ok = await controller.sendStudyInvite(target);
                    if (context.mounted) showSnack(context, ok ? 'Undangan belajar dikirim.' : controller.lastError, error: !ok);
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Undang'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AiCoachTab extends StatefulWidget {
  const AiCoachTab({super.key, required this.controller});
  final AppController controller;

  @override
  State<AiCoachTab> createState() => _AiCoachTabState();
}

class _AiCoachTabState extends State<AiCoachTab> {
  final message = TextEditingController();

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final ok = await widget.controller.askCoach(message.text);
    if (ok) message.clear();
    if (!ok && mounted) showSnack(context, widget.controller.lastError, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.controller.studyPlan;
    return RefreshIndicator(
      onRefresh: () => widget.controller.loadStudyPlan(force: true),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        children: [
          SectionTitle(
            'AI Study Assistant',
            subtitle: 'Study plan dan coach dari backend Laravel.',
            action: IconButton(onPressed: () => widget.controller.loadStudyPlan(force: true), icon: const Icon(Icons.refresh_rounded)),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Study Plan', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (plan == null)
                  const Text('Tarik ke bawah untuk memuat study plan.', style: TextStyle(color: kMuted))
                else
                  StudyPlanView(plan: plan),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('AI Coach'),
          const SizedBox(height: 10),
          ...widget.controller.coachMessages.map((m) => MessageBubble(message: asMap(m), currentUserId: 'Me')),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: TextField(controller: message, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Tanya AI Coach...', border: InputBorder.none), onSubmitted: (_) => send())),
                IconButton.filled(onPressed: widget.controller.busy ? null : send, icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudyPlanView extends StatelessWidget {
  const StudyPlanView({super.key, required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final recommendations = asList(plan['recommendations'] ?? plan['items'] ?? plan['plan']);
    final priorities = asList(plan['priorities']);
    final sessions = asList(plan['sessions']);
    final tips = asList(plan['tips']);
    final focusWindow = textOrNull(plan, ['recommendedFocusWindow']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(textOf(plan, ['headline', 'summary', 'message'], fallback: 'Rencana belajar tersedia.')),
        if (focusWindow != null) ...[
          const SizedBox(height: 8),
          Pill('Fokus utama: $focusWindow', icon: Icons.bolt_rounded, color: kWarn),
        ],
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Sesi Belajar', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...sessions.take(8).map((s) => StudySessionTile(session: asMap(s))),
        ],
        if (priorities.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Prioritas', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...priorities.take(5).map((p) => BulletText(p.toString())),
        ],
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Rekomendasi', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...recommendations.take(8).map((r) {
            if (r is Map) return BulletText(textOf(r, ['title', 'label', 'message', 'description'], fallback: jsonEncode(r)));
            return BulletText(r.toString());
          }),
        ],
        if (tips.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Tips', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...tips.take(4).map((t) => BulletText(t.toString())),
        ],
        if (priorities.isEmpty && recommendations.isEmpty && sessions.isEmpty && tips.isEmpty) ...[
          const SizedBox(height: 8),
          Text(jsonEncode(plan), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
        ],
      ],
    );
  }
}

class BulletText extends StatelessWidget {
  const BulletText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.controller});
  final AppController controller;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final picker = ImagePicker();
  final name = TextEditingController();
  final email = TextEditingController();
  final university = TextEditingController();
  final studentId = TextEditingController();
  final bio = TextEditingController();
  final interestSearch = TextEditingController();
  final courseSearch = TextEditingController();

  bool loaded = false;
  int semesterValue = 1;
  String selectedProgramId = '';
  String avatarColor = '#6366F1';
  final Set<String> selectedInterestCodes = <String>{};
  final Set<String> selectedCourseIds = <String>{};
  List<Map<String, dynamic>> scheduleSlots = <Map<String, dynamic>>[];

  String draftCourseId = '';
  String draftDay = 'SENIN';
  String draftTime = '19:00';
  int draftDuration = 90;

  static const List<Map<String, String>> interestCatalog = [
    {'code': 'AI', 'label': 'Kecerdasan Buatan'},
    {'code': 'ML', 'label': 'Machine Learning'},
    {'code': 'DATA', 'label': 'Data Analytics / Data Science'},
    {'code': 'WEB', 'label': 'Web Development'},
    {'code': 'MOBILE', 'label': 'Mobile Development'},
    {'code': 'UIUX', 'label': 'UI/UX dan Product Design'},
    {'code': 'CYBERSEC', 'label': 'Keamanan Siber'},
    {'code': 'CLOUD', 'label': 'Cloud Computing'},
    {'code': 'IOT', 'label': 'Internet of Things'},
    {'code': 'DB', 'label': 'Database dan SQL'},
    {'code': 'PM', 'label': 'Project Management'},
    {'code': 'BISNIS', 'label': 'Bisnis Digital'},
    {'code': 'MARKETING', 'label': 'Digital Marketing'},
    {'code': 'BRANDING', 'label': 'Branding dan Identitas Visual'},
    {'code': 'DESAIN', 'label': 'Desain Visual'},
    {'code': 'PUBLIC-SPEAKING', 'label': 'Public Speaking'},
    {'code': 'PR', 'label': 'Public Relations'},
    {'code': 'AKUNTANSI', 'label': 'Akuntansi'},
    {'code': 'FINANCE', 'label': 'Keuangan'},
    {'code': 'STATISTIK', 'label': 'Statistika'},
    {'code': 'RISET', 'label': 'Metodologi Penelitian'},
    {'code': 'SKRIPSI', 'label': 'Tugas Akhir / Skripsi'},
  ];

  static const days = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU'];
  static const durations = [60, 90, 120, 150];
  static final timeOptions = List.generate(17, (i) => '${(i + 6).toString().padLeft(2, '0')}:00');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      fill();
      loaded = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    university.dispose();
    studentId.dispose();
    bio.dispose();
    interestSearch.dispose();
    courseSearch.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get programs => asList(widget.controller.bootstrap?['programs']).map((e) => asMap(e)).where((p) => textOf(p, ['id'], fallback: '').isNotEmpty).toList();
  List<Map<String, dynamic>> get allCourses => asList(widget.controller.bootstrap?['courses']).map((e) => asMap(e)).where((c) => textOf(c, ['id'], fallback: '').isNotEmpty).toList();

  Map<String, dynamic>? get selectedProgram {
    for (final p in programs) {
      if (textOf(p, ['id'], fallback: '') == selectedProgramId) return p;
    }
    return null;
  }

  String get selectedProgramName => textOf(selectedProgram, ['name'], fallback: textOf(widget.controller.user, ['program_name', 'programName'], fallback: ''));

  Map<String, dynamic>? courseById(String id) {
    for (final c in allCourses) {
      if (textOf(c, ['id'], fallback: '') == id) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> get selectedCourses {
    return selectedCourseIds.map(courseById).whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> get filteredCourses {
    final q = courseSearch.text.trim().toUpperCase();
    final result = allCourses.where((course) {
      final id = textOf(course, ['id'], fallback: '');
      if (selectedCourseIds.contains(id)) return false;
      final programId = textOf(course, ['programId', 'program_id'], fallback: '');
      if (q.isEmpty && selectedProgramId.isNotEmpty && programId != selectedProgramId) return false;
      final program = asMap(course['program']);
      final haystack = [
        textOf(course, ['code'], fallback: ''),
        textOf(course, ['name'], fallback: ''),
        textOf(program, ['name'], fallback: ''),
        textOf(program, ['faculty'], fallback: ''),
      ].join(' ').toUpperCase();
      return q.isEmpty || haystack.contains(q);
    }).toList();
    result.sort((a, b) => '${textOf(a, ['code'], fallback: '')} ${textOf(a, ['name'], fallback: '')}'.compareTo('${textOf(b, ['code'], fallback: '')} ${textOf(b, ['name'], fallback: '')}'));
    return result.take(80).toList();
  }

  List<Map<String, String>> get filteredInterests {
    final q = interestSearch.text.trim().toUpperCase();
    return interestCatalog.where((item) {
      final code = item['code'] ?? '';
      if (selectedInterestCodes.contains(code)) return false;
      final label = item['label'] ?? '';
      return q.isEmpty || '$code $label'.toUpperCase().contains(q);
    }).toList();
  }

  void fill() {
    final u = widget.controller.user;
    name.text = textOf(u, ['name'], fallback: '');
    email.text = textOf(u, ['email'], fallback: '');
    university.text = textOf(u, ['university'], fallback: '');
    studentId.text = textOf(u, ['studentId', 'student_id'], fallback: '');
    bio.text = textOf(u, ['bio'], fallback: '');
    semesterValue = intOf(u, ['semester'], fallback: 1).clamp(1, 8).toInt();
    selectedProgramId = textOf(u, ['programId', 'program_id'], fallback: '');
    avatarColor = textOf(u, ['avatarColor', 'avatar_color'], fallback: '#6366F1');
    selectedInterestCodes
      ..clear()
      ..addAll(asList(asMap(u)['interests']).map((e) => e.toString().trim().toUpperCase()).where((e) => e.isNotEmpty));
    final fromCourseIds = asList(asMap(u)['courseIds']).map((e) => e.toString());
    final fromCourses = asList(asMap(u)['courses']).map((e) => textOf(asMap(e), ['id'], fallback: ''));
    selectedCourseIds
      ..clear()
      ..addAll([...fromCourseIds, ...fromCourses].where((e) => e.trim().isNotEmpty));
    scheduleSlots = normalizeAvailability(asList(asMap(u)['availability']));
    if (selectedCourseIds.isNotEmpty && draftCourseId.isEmpty) draftCourseId = selectedCourseIds.first;
  }

  List<Map<String, dynamic>> normalizeAvailability(List<dynamic> raw) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map) {
        final slot = asMap(item);
        final day = textOf(slot, ['day'], fallback: '').toUpperCase();
        final time = textOf(slot, ['time'], fallback: '');
        if (days.contains(day) && RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
          final cid = textOf(slot, ['courseId', 'course_id'], fallback: selectedCourseIds.isNotEmpty ? selectedCourseIds.first : '');
          final c = courseById(cid);
          out.add({
            'courseId': cid,
            'courseCode': textOf(slot, ['courseCode'], fallback: textOf(c, ['code'], fallback: '')),
            'courseName': textOf(slot, ['courseName'], fallback: textOf(c, ['name'], fallback: 'Mata kuliah')),
            'day': day,
            'time': time,
            'durationMinutes': intOf(slot, ['durationMinutes'], fallback: 90),
          });
        }
      } else if (item is String) {
        final parts = item.toUpperCase().replaceAll('.', ':').split(RegExp(r'\s+'));
        String? day;
        String? time;
        for (final part in parts) {
          if (days.contains(part)) day = part;
          if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(part)) {
            final h = part.split(':').first.padLeft(2, '0');
            time = '$h:${part.split(':').last}';
          }
        }
        if (day != null && time != null) {
          final cid = selectedCourseIds.isNotEmpty ? selectedCourseIds.elementAt(i % selectedCourseIds.length) : '';
          final c = courseById(cid);
          out.add({
            'courseId': cid,
            'courseCode': textOf(c, ['code'], fallback: ''),
            'courseName': textOf(c, ['name'], fallback: 'Mata kuliah'),
            'day': day,
            'time': time,
            'durationMinutes': 90,
          });
        }
      }
    }
    return out;
  }

  void addInterest(Map<String, String> item) {
    setState(() {
      selectedInterestCodes.add((item['code'] ?? '').toUpperCase());
      interestSearch.clear();
    });
  }

  void addManualInterest() {
    final code = interestSearch.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\- ]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    if (code.isEmpty) return;
    setState(() {
      selectedInterestCodes.add(code);
      interestSearch.clear();
    });
  }

  void addCourse(Map<String, dynamic> course) {
    final id = textOf(course, ['id'], fallback: '');
    if (id.isEmpty) return;
    setState(() {
      selectedCourseIds.add(id);
      draftCourseId = draftCourseId.isEmpty ? id : draftCourseId;
      courseSearch.clear();
    });
  }

  void removeCourse(String id) {
    setState(() {
      selectedCourseIds.remove(id);
      scheduleSlots = scheduleSlots.where((slot) => textOf(slot, ['courseId'], fallback: '') != id).toList();
      if (draftCourseId == id) draftCourseId = selectedCourseIds.isNotEmpty ? selectedCourseIds.first : '';
    });
  }

  void addScheduleSlot() {
    final actualCourseId = selectedCourseIds.contains(draftCourseId)
        ? draftCourseId
        : (selectedCourseIds.isNotEmpty ? selectedCourseIds.first : '');
    if (actualCourseId.isEmpty) {
      showSnack(context, 'Pilih mata kuliah aktif dulu sebelum menambah jadwal.', error: true);
      return;
    }
    draftCourseId = actualCourseId;
    final course = courseById(actualCourseId);
    final duplicate = scheduleSlots.any((slot) => textOf(slot, ['courseId'], fallback: '') == actualCourseId && textOf(slot, ['day'], fallback: '') == draftDay && textOf(slot, ['time'], fallback: '') == draftTime);
    if (duplicate) {
      showSnack(context, 'Slot jadwal tersebut sudah ada.', error: true);
      return;
    }
    setState(() {
      scheduleSlots.add({
        'courseId': actualCourseId,
        'courseCode': textOf(course, ['code'], fallback: ''),
        'courseName': textOf(course, ['name'], fallback: 'Mata kuliah'),
        'day': draftDay,
        'time': draftTime,
        'durationMinutes': draftDuration,
      });
    });
  }

  Map<String, dynamic>? programPayload() {
    final p = selectedProgram;
    if (p == null) return null;
    return {
      'id': textOf(p, ['id'], fallback: ''),
      'name': textOf(p, ['name'], fallback: ''),
      'faculty': textOf(p, ['faculty'], fallback: ''),
    };
  }

  List<Map<String, dynamic>> selectedCoursePayloads() {
    return selectedCourses.map((course) {
      final program = asMap(course['program']);
      final programId = textOf(course, ['programId', 'program_id'], fallback: '');
      return {
        'id': textOf(course, ['id'], fallback: ''),
        'code': textOf(course, ['code'], fallback: '').toUpperCase(),
        'name': textOf(course, ['name'], fallback: ''),
        'programId': programId,
        'programName': textOf(program, ['name'], fallback: selectedProgramName),
        'faculty': textOf(program, ['faculty'], fallback: ''),
      };
    }).where((payload) => (payload['id'] as String).isNotEmpty).toList();
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    final ok = await widget.controller.updateProfile({
      'name': name.text.trim(),
      'email': email.text.trim(),
      'university': university.text.trim().toUpperCase(),
      'programId': selectedProgramId.isEmpty ? null : selectedProgramId,
      'programName': selectedProgramName.toUpperCase(),
      'programPayload': programPayload(),
      'studentId': studentId.text.trim(),
      'semester': semesterValue,
      'bio': bio.text.trim(),
      'interests': selectedInterestCodes.toList(),
      'courseIds': selectedCourseIds.toList(),
      'selectedCoursePayloads': selectedCoursePayloads(),
      'availability': scheduleSlots,
      'avatarColor': avatarColor,
    });
    if (!mounted) return;
    if (ok) {
      fill();
      setState(() {});
    }
    showSnack(context, ok ? 'Profil akademik berhasil disimpan.' : widget.controller.lastError, error: !ok);
  }

  Future<XFile?> pickLocalImageFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: false,
      );
      final path = result?.files.single.path;
      if (path != null && path.isNotEmpty) return XFile(path);
    } catch (_) {
      // Fallback untuk perangkat yang tidak membuka file manager.
    }
    return picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2000);
  }

  Future<void> pickAvatar() async {
    final file = await pickLocalImageFile();
    if (file == null) return;
    final ok = await widget.controller.uploadAvatar(file);
    if (!mounted) return;
    if (ok) {
      fill();
      setState(() {});
    }
    showSnack(context, ok ? 'Foto profil berhasil diunggah.' : widget.controller.lastError, error: !ok);
  }

  Future<void> pickKtm() async {
    final file = await pickLocalImageFile();
    if (file == null) return;
    final ok = await widget.controller.uploadKtm(file);
    if (!mounted) return;
    if (ok) {
      fill();
      setState(() {});
    }
    showSnack(context, ok ? 'KTM berhasil dikirim ke sistem verifikasi.' : widget.controller.lastError, error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final verification = textOf(widget.controller.user, ['verificationStatus', 'verification_status'], fallback: 'unverified');
    final progress = verification == 'fully_verified' ? 100 : (verification == 'half_verified' ? 50 : 0);
    final avatarUrl = textOrNull(widget.controller.user, ['avatarUrl', 'avatar_url']);
    final validDraftCourseId = selectedCourses.any((c) => textOf(c, ['id'], fallback: '') == draftCourseId)
        ? draftCourseId
        : (selectedCourses.isEmpty ? '' : textOf(selectedCourses.first, ['id'], fallback: ''));
    final validProgramId = programs.any((p) => textOf(p, ['id'], fallback: '') == selectedProgramId) ? selectedProgramId : '';

    return RefreshIndicator(
      onRefresh: () async {
        await widget.controller.bootstrapApp(silent: true);
        await widget.controller.loadProfile();
        fill();
        if (mounted) setState(() {});
      },
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        children: [
          SectionTitle('Kelola Profil', subtitle: 'Disesuaikan dengan modul Profil Akademik & Minat pada web StudyMate.'),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: avatarUrl != null
                          ? Image.network(avatarUrl, width: 66, height: 66, fit: BoxFit.cover, errorBuilder: (_, __, ___) => AvatarBadge(name: widget.controller.userName, size: 66))
                          : AvatarBadge(name: widget.controller.userName, size: 66, color: colorFromSeed(avatarColor)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.controller.userName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('Status verifikasi: $verification', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress / 100, minHeight: 7, borderRadius: BorderRadius.circular(99)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: widget.controller.busy ? null : pickAvatar, icon: const Icon(Icons.photo_camera_rounded), label: const Text('Browse Foto'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: widget.controller.busy ? null : pickKtm, icon: const Icon(Icons.badge_rounded), label: const Text('Browse KTM'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Data Utama', subtitle: 'Informasi identitas mahasiswa.'),
                const SizedBox(height: 12),
                TextField(controller: name, textCapitalization: TextCapitalization.characters, inputFormatters: const [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: 'Nama Lengkap')),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: studentId, textCapitalization: TextCapitalization.characters, inputFormatters: const [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: 'NIM / Student ID')),
                const SizedBox(height: 10),
                TextField(controller: university, textCapitalization: TextCapitalization.characters, inputFormatters: const [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: 'Universitas')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: validProgramId.isEmpty ? null : validProgramId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Program Studi'),
                  items: programs.map((p) {
                    final id = textOf(p, ['id'], fallback: '');
                    final name = textOf(p, ['name'], fallback: id);
                    final faculty = textOf(p, ['faculty'], fallback: '');
                    return DropdownMenuItem(value: id, child: Text(faculty.isEmpty ? name : '$name — $faculty', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedProgramId = value ?? ''),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: semesterValue,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: List.generate(8, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('Semester $v'))).toList(),
                  onChanged: (value) => setState(() => semesterValue = value ?? 1),
                ),
                const SizedBox(height: 10),
                TextField(controller: bio, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Bio Singkat')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Akademik & Minat', subtitle: 'Pilih minat dan mata kuliah dari katalog, seperti versi web.'),
                const SizedBox(height: 12),
                Text('Minat Akademik', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: kMuted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (selectedInterestCodes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedInterestCodes.map((code) => InputChip(label: Text(code), onDeleted: () => setState(() => selectedInterestCodes.remove(code)))).toList(),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: interestSearch,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: const [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(labelText: 'Cari kode/minat: AI, WEB, DATA, UIUX...'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => filteredInterests.isNotEmpty ? addInterest(filteredInterests.first) : addManualInterest(),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ...filteredInterests.map((item) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Pill(item['code'] ?? '', color: kPrimary),
                            title: Text(item['label'] ?? ''),
                            onTap: () => addInterest(item),
                          )),
                      if (interestSearch.text.trim().isNotEmpty && filteredInterests.isEmpty)
                        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.add_rounded), title: Text('Tambah minat manual: ${interestSearch.text.toUpperCase()}'), onTap: addManualInterest),
                    ],
                  ),
                ),
                const Divider(height: 28),
                Text('Mata Kuliah Aktif', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: kMuted, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (selectedCourses.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedCourses.map((course) {
                      final id = textOf(course, ['id'], fallback: '');
                      final label = '${textOf(course, ['code'], fallback: '')} — ${textOf(course, ['name'], fallback: '')}';
                      return InputChip(label: Text(label), onDeleted: () => removeCourse(id));
                    }).toList(),
                  )
                else
                  Text('Belum ada mata kuliah dipilih.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
                const SizedBox(height: 8),
                TextField(
                  controller: courseSearch,
                  decoration: const InputDecoration(labelText: 'Cari mata kuliah dari katalog'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => filteredCourses.isNotEmpty ? addCourse(filteredCourses.first) : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = filteredCourses[index];
                      final program = asMap(course['program']);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.menu_book_rounded, color: kAccent),
                        title: Text(textOf(course, ['name'], fallback: 'Mata kuliah')),
                        subtitle: Text('${textOf(course, ['code'], fallback: '')} · ${textOf(program, ['name'], fallback: selectedProgramName)}'),
                        onTap: () => addCourse(course),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Jadwal Belajar per Mata Kuliah', subtitle: 'Slot terstruktur agar rekomendasi jadwal di dashboard lebih akurat.'),
                const SizedBox(height: 12),
                if (selectedCourses.isEmpty)
                  const EmptyCard(icon: Icons.info_outline_rounded, title: 'Pilih mata kuliah dulu', subtitle: 'Jadwal belajar harus ditautkan ke mata kuliah aktif.')
                else ...[
                  DropdownButtonFormField<String>(
                    value: validDraftCourseId.isEmpty ? null : validDraftCourseId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mata Kuliah'),
                    items: selectedCourses.map((course) {
                      final id = textOf(course, ['id'], fallback: '');
                      final label = '${textOf(course, ['code'], fallback: '')} — ${textOf(course, ['name'], fallback: '')}';
                      return DropdownMenuItem(value: id, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (value) => setState(() => draftCourseId = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: draftDay,
                          decoration: const InputDecoration(labelText: 'Hari'),
                          items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (value) => setState(() => draftDay = value ?? 'SENIN'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: draftTime,
                          decoration: const InputDecoration(labelText: 'Jam'),
                          items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (value) => setState(() => draftTime = value ?? '19:00'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: draftDuration,
                    decoration: const InputDecoration(labelText: 'Durasi'),
                    items: durations.map((d) => DropdownMenuItem(value: d, child: Text('$d menit'))).toList(),
                    onChanged: (value) => setState(() => draftDuration = value ?? 90),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: addScheduleSlot, icon: const Icon(Icons.add_rounded), label: const Text('Tambah Slot Jadwal')),
                ],
                if (scheduleSlots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...scheduleSlots.map((slot) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: kLine), borderRadius: BorderRadius.circular(14), color: const Color(0x6610172A)),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: kWarn),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${textOf(slot, ['courseCode'], fallback: '')} — ${textOf(slot, ['courseName'], fallback: 'Mata kuliah')}\n${textOf(slot, ['day'], fallback: '')} ${textOf(slot, ['time'], fallback: '')} · ${intOf(slot, ['durationMinutes'], fallback: 90)} menit'),
                            ),
                            IconButton(onPressed: () => setState(() => scheduleSlots.remove(slot)), icon: const Icon(Icons.close_rounded)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Simpan Semua Perubahan', icon: Icons.save_rounded, loading: widget.controller.busy, onPressed: save),
          const SizedBox(height: 18),
          SectionTitle('Teman Belajar', action: IconButton(onPressed: () => widget.controller.loadFriends(), icon: const Icon(Icons.refresh_rounded))),
          const SizedBox(height: 10),
          if (widget.controller.friends.isEmpty)
            const EmptyCard(icon: Icons.people_outline_rounded, title: 'Belum ada teman', subtitle: 'Terima undangan belajar atau kirim undangan dari tab Smart Match.')
          else
            ...widget.controller.friends.map((f) => FriendTile(controller: widget.controller, friend: asMap(f))),
        ],
      ),
    );
  }
}

class FriendTile extends StatelessWidget {
  const FriendTile({super.key, required this.controller, required this.friend});
  final AppController controller;
  final Map<String, dynamic> friend;

  @override
  Widget build(BuildContext context) {
    final name = textOf(friend, ['name'], fallback: 'Teman');
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: AvatarBadge(name: name),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(textOf(friend, ['program_name', 'program', 'programName'], fallback: '')),
        trailing: IconButton.filledTonal(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(controller: controller, friend: friend))),
          icon: const Icon(Icons.chat_rounded),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadNotifications(silent: true).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [TextButton(onPressed: () async { final ok = await widget.controller.markAllNotificationsRead(); if (!context.mounted) return; showSnack(context, ok ? 'Semua notifikasi ditandai dibaca.' : widget.controller.lastError, error: !ok); if (mounted) setState(() {}); }, child: const Text('Baca semua'))],
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await widget.controller.loadNotifications();
          if (mounted) setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.controller.notifications.isEmpty)
              const EmptyCard(icon: Icons.notifications_none_rounded, title: 'Belum ada notifikasi', subtitle: 'Undangan dan pesan baru akan tampil di sini.')
            else
              ...widget.controller.notifications.map((n) => NotificationCard(controller: widget.controller, notification: asMap(n), onChanged: () => setState(() {}))),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatefulWidget {
  const NotificationCard({super.key, required this.controller, required this.notification, required this.onChanged});
  final AppController controller;
  final Map<String, dynamic> notification;
  final VoidCallback onChanged;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool actionBusy = false;

  Future<void> runAction(Future<bool> Function() action, String successMessage) async {
    if (actionBusy) return;
    setState(() => actionBusy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => actionBusy = false);
    showSnack(context, ok ? successMessage : widget.controller.lastError, error: !ok);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final controller = widget.controller;
    final id = textOf(notification, ['id'], fallback: '');
    final type = textOf(notification, ['type'], fallback: 'notification');
    final unread = textOrNull(notification, ['readAt', 'read_at']) == null;
    final data = asMap(notification['data']);
    final status = textOf(data, ['status'], fallback: '');
    final isPendingInvite = type == 'study_invite' && (status.isEmpty || status == 'pending');
    final sender = asMap(notification['sender']);
    final senderName = textOf(data, ['senderName'], fallback: textOf(sender, ['name'], fallback: ''));

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(unread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: unread ? kWarn : kMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  textOf(notification, ['message'], fallback: '-'),
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(notificationTypeLabel(type), icon: Icons.label_rounded),
              if (status.isNotEmpty) Pill(notificationStatusLabel(status), icon: Icons.info_rounded, color: notificationStatusColor(status)),
              if (senderName.isNotEmpty) Pill('Dari $senderName', icon: Icons.person_rounded, color: kAccent),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: actionBusy ? null : () => runAction(() => controller.markNotificationRead(id), 'Notifikasi ditandai sudah dibaca.'),
              icon: actionBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_rounded),
              label: const Text('Tandai dibaca'),
            ),
          ),
          if (isPendingInvite) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionBusy ? null : () => runAction(() => controller.acceptInvite(id), 'Undangan diterima. Pengguna ditambahkan sebagai teman belajar.'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Terima'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: actionBusy ? null : () => runAction(() => controller.rejectInvite(id), 'Undangan ditolak.'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller, required this.friend});
  final AppController controller;
  final Map<String, dynamic> friend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final text = TextEditingController();
  List<dynamic> messages = [];
  bool loading = true;

  String get friendId => textOf(widget.friend, ['id'], fallback: '');
  String get friendName => textOf(widget.friend, ['name'], fallback: 'Chat');

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      messages = await widget.controller.getPrivateMessages(friendId);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    if (text.text.trim().isEmpty) return;
    try {
      await widget.controller.sendPrivateMessage(friendId, text.text);
      text.clear();
      await load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(friendName), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
      child: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      children: messages.isEmpty
                          ? [const EmptyCard(icon: Icons.chat_bubble_outline_rounded, title: 'Belum ada pesan', subtitle: 'Mulai percakapan.')] 
                          : messages.map((m) => MessageBubble(message: asMap(m), currentUserId: widget.controller.userId ?? '')).toList(),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: text, decoration: const InputDecoration(hintText: 'Tulis pesan...', border: InputBorder.none), onSubmitted: (_) => send())),
                    IconButton.filled(onPressed: send, icon: const Icon(Icons.send_rounded)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
