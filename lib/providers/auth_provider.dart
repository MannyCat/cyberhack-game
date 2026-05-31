import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<Session?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<Session?>> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;

  AuthNotifier() : super(const AsyncValue.loading()) {
    // Seed initial state from current session if already logged in
    final existingSession = _supabase.auth.currentSession;
    if (existingSession != null) {
      state = AsyncValue.data(existingSession);
    }
    // Listen for all subsequent auth state changes
    _sub = _supabase.auth.onAuthStateChange.listen((authState) {
      state = AsyncValue.data(authState.session);
    });
  }

  // ── Convenience getters ──────────────────────────────────────────────
  String? get username =>
      _supabase.auth.currentUser?.userMetadata?['username'] as String?;

  String? get email => _supabase.auth.currentUser?.email;

  User? get user => _supabase.auth.currentUser;

  Session? get currentSession => state.valueOrNull;

  bool get isAuthenticated => state.valueOrNull != null;

  // ── Error message helper ─────────────────────────────────────────────
  String? get errorMessage {
    final err = state.error;
    if (err is AuthException) {
      // Translate common Supabase errors to Russian
      final msg = err.message.toLowerCase();
      if (msg.contains('invalid login')) {
        return 'Неверный email или пароль';
      }
      if (msg.contains('email not confirmed')) {
        return 'Подтвердите email перед входом';
      }
      if (msg.contains('user already registered') ||
          msg.contains('already registered')) {
        return 'Этот email уже зарегистрирован';
      }
      if (msg.contains('password') && msg.contains('weak')) {
        return 'Пароль слишком слабый (минимум 6 символов)';
      }
      return err.message;
    }
    if (err != null) return err.toString();
    return null;
  }

  // ── Actions ───────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> register(String email, String password, String username) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
    } on AuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
