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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
  String get displayName => _profile?.username ?? _user?.email ?? 'Unknown';
  bool get isAuthenticated => _authState == AuthState.authenticated;

  // --- Initialization ---

  void _initAuth() {
    // Check existing session
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _user = session.user;
      _loadProfile();
    } else {
      _authState = AuthState.unauthenticated;
      notifyListeners();
    }

    // Listen for auth state changes
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
          .single();

      _profile = PlayerProfile.fromJson(response);
      _errorMessage = null;
    } catch (e) {
      debugPrint('Error loading profile: $e');
      _errorMessage = 'Failed to load profile';
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
      // _onAuthStateChange will handle the state update
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
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
      // Sign up the user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      // If email confirmation is not required, update profile directly
      if (response.user != null && response.session != null) {
        // Profile should be auto-created via trigger, but update username
        await _supabase.from('profiles').update({
          'username': username,
        }).eq('id', response.user!.id);

        // _onAuthStateChange will handle the state update
        return true;
      }

      // Email confirmation required
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
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
      debugPrint('Error logging out: $e');
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
      _errorMessage = 'An unexpected error occurred';
      return false;
    }
  }

  // --- Error Mapping ---

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) return 'Invalid email or password';
    if (lower.contains('email not confirmed')) return 'Please verify your email address';
    if (lower.contains('user already registered')) return 'An account with this email already exists';
    if (lower.contains('password')) return 'Password must be at least 6 characters';
    if (lower.contains('network')) return 'Network error. Please check your connection';
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
