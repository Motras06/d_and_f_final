import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/role_model.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;

  Future<Profile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; 
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Неизвестная ошибка при входе';
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String? username,
    required AppRole role,
  }) async {
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return 'Не удалось создать пользователя';
      }

      await _supabase.from('profiles').insert({
        'id': user.id,
        'mail': email,
        'username': username?.trim().isNotEmpty == true ? username!.trim() : null,
        'role': appRoleToString(role),
      });

      return null; 
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Ошибка при регистрации: $e';
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}