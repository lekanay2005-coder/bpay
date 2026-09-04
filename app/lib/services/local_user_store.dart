import 'package:shared_preferences/shared_preferences.dart';

/// Persists the local PayFlex user id across app launches so we never
/// re-run user creation on relaunch — per the build brief, recreating a
/// BMONI user forks wallet history. This is checked before ever calling
/// the backend's POST /users endpoint.
class LocalUserStore {
  static const _appUserIdKey = 'payflex.appUserId';

  Future<String?> getAppUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appUserIdKey);
  }

  Future<void> setAppUserId(String appUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appUserIdKey, appUserId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appUserIdKey);
  }
}
