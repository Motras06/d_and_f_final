import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalStorage {
  static const _keyAccount = 'df_current_account';
  static const String _storeKey = 'df_assigned_store';

  static Future<void> saveAccount(Map<String, String> account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccount, jsonEncode(account));
  }

  static Future<Map<String, String>?> getSavedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyAccount);
    if (s == null) return null;
    final map = jsonDecode(s) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  }

  static Future<void> clearAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccount);
  }

  static Future<void> saveStore(String? store) async {
    final prefs = await SharedPreferences.getInstance();
    if (store == null) {
      await prefs.remove(_storeKey);
    } else {
      await prefs.setString(_storeKey, store);
    }
  }

  static Future<String?> getSavedStore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storeKey);
  }
}