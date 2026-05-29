import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthState { loading, authenticated, unauthenticated }

class PlayerProfile {
  final String id;
  final String username;
  final int credits;
  final int cpu;
  final int bandwidth;
  final int level;
  final int experience;
  final String? clanId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlayerProfile({
    required this.id,
    required this.username,
    required this.credits,
    required this.cpu,
    required this.bandwidth,
    required this.level,
    required this.experience,
    this.clanId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      cpu: (json['cpu'] as num?)?.toInt() ?? 0,
      bandwidth: (json['bandwidth'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      clanId: json['clan_id'] as String?,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? (DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()) : DateTime.now(),
    );
  }

  PlayerProfile copyWith({
    String? id,
    String? username,
    int? credits,
    int? cpu,
    int? bandwidth,
    int? level,
    int? experience,
    String? clanId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      credits: credits ?? this.credits,
      cpu: cpu ?? this.cpu,
      bandwidth: bandwidth ?? this.bandwidth,
      level: level ?? this.level,
      experience: experience ?? this.experience,
      clanId: clanId ?? this.clanId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// AuthProvider работает как ChangeNotifier + Listenable
/// чтобы GoRouter мог использовать refreshListenable
class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  AuthState _authState = AuthState.loading;
  User? _user;
  PlayerProfile? _profile;
  String? _errorMessage;
  StreamSubscription? _authSubscription;

  AuthProvider() {
    _initAuth();
  }

  // --- Getters ---

  AuthState get authState => _authState;
  User? get user => _user;
  PlayerProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  String? get userId => _user?.id;
  String get displayName => _profile?.username ?? _user?.email ?? 'Неизвестный';
  bool get isAuthenticated => _authState == AuthState.authenticated;

  // --- Initialization ---

  void _initAuth() {
    // Проверяем существующую сессию
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _user = session.user;
      _loadProfile();
    } else {
      _authState = AuthState.unauthenticated;
      notifyListeners();
    }

    // Слушаем изменения состояния авторизации
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      _onAuthStateChange(state.event);
    });
  }

  Future<void> _onAuthStateChange(AuthChangeEvent event) async {
    switch (event) {
      case AuthChangeEvent.signedIn:
        _user = _supabase.auth.currentUser;
        _authState = AuthState.authenticated;
        await _loadProfile();
        break;
      case AuthChangeEvent.signedOut:
        _user = null;
        _profile = null;
        _authState = AuthState.unauthenticated;
        break;
      case AuthChangeEvent.tokenRefreshed:
        _user = _supabase.auth.currentUser;
        break;
      case AuthChangeEvent.userDeleted:
        _user = null;
        _profile = null;
        _authState = AuthState.unauthenticated;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  // --- Profile ---

  Future<void> _loadProfile() async {
    if (_user == null) return;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();

      if (response != null) {
        _profile = PlayerProfile.fromJson(response);
        _errorMessage = null;
      } else {
        // Profile doesn't exist yet — create it
        try {
          final username = _user!.userMetadata?['username'] ??
              _user!.email?.split('@')[0] ?? 'Хакер';
          await _supabase.from('profiles').insert({
            'id': _user!.id,
            'username': username,
            'credits': 1000,
            'cpu': 200,
            'bandwidth': 200,
            'level': 1,
            'experience': 0,
          });
          _profile = PlayerProfile(
            id: _user!.id,
            username: username,
            credits: 1000,
            cpu: 200,
            bandwidth: 200,
            level: 1,
            experience: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _errorMessage = null;
        } catch (createErr) {
          debugPrint('Ошибка создания профиля: $createErr');
          // Don't block auth — user can still navigate
          _profile = PlayerProfile(
            id: _user!.id,
            username: _user!.email?.split('@')[0] ?? 'Хакер',
            credits: 1000,
            cpu: 200,
            bandwidth: 200,
            level: 1,
            experience: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
      // Set default profile instead of blocking
      _profile = PlayerProfile(
        id: _user!.id,
        username: _user!.email?.split('@')[0] ?? 'Хакер',
        credits: 1000,
        cpu: 200,
        bandwidth: 200,
        level: 1,
        experience: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  // --- Authentication ---

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _authState = AuthState.loading;
    notifyListeners();

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // _onAuthStateChange обработает обновление состояния
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Произошла непредвиденная ошибка';
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String username,
  }) async {
    _errorMessage = null;
    _authState = AuthState.loading;
    notifyListeners();

    try {
      // Регистрация пользователя
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      // Если подтверждение email не требуется, обновляем профиль
      if (response.user != null && response.session != null) {
        // Профиль должен быть создан автоматически через триггер,
        // но обновляем username для надёжности
        try {
          await _supabase.from('profiles').update({
            'username': username,
          }).eq('id', response.user!.id);
        } catch (e) {
          debugPrint('Профиль создан через триггер, обновление не требуется: $e');
        }

        // _onAuthStateChange обработает обновление состояния
        return true;
      }

      // Требуется подтверждение email
      if (response.user != null) {
        _authState = AuthState.unauthenticated;
        _errorMessage = 'Проверьте вашу почту для подтверждения аккаунта';
        notifyListeners();
        return true;
      }

      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Произошла непредвиденная ошибка';
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      _profile = null;
      _user = null;
      _authState = AuthState.unauthenticated;
    } catch (e) {
      debugPrint('Ошибка выхода: $e');
    }
    notifyListeners();
  }

  Future<bool> resetPassword({required String email}) async {
    _errorMessage = null;

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      return false;
    } catch (e) {
      _errorMessage = 'Произошла непредвиденная ошибка';
      return false;
    }
  }

  // --- Error Mapping (на русском) ---

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Неверный email или пароль';
    }
    if (lower.contains('email not confirmed')) {
      return 'Подтвердите ваш адрес электронной почты';
    }
    if (lower.contains('user already registered') || lower.contains('already been registered')) {
      return 'Аккаунт с такой почтой уже существует';
    }
    if (lower.contains('password')) {
      return 'Пароль должен быть не менее 6 символов';
    }
    if (lower.contains('network') || lower.contains('fetch')) {
      return 'Ошибка сети. Проверьте подключение к интернету';
    }
    if (lower.contains('rate limit')) {
      return 'Слишком много попыток. Подождите немного';
    }
    if (lower.contains('to redirect')) {
      return 'Неверный URL перенаправления в настройках Supabase';
    }
    return message;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
