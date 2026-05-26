import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  ApiClient get api => _api;
  bool get isAuthenticated => _api.isAuthenticated;
  String? get token => _api.token;
  String? get userUuid => _api.userUuid;
  String? get username => _api.username;
  String? get role => _api.role;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<bool> login(String user, String pass, {bool remember = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.login(user, pass);
      if (_api.isAuthenticated) {
        if (remember) {
          await _api.saveCredentials(user, pass);
        } else {
          await _api.clearSavedCredentials();
        }
        _loading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '网络连接失败: $e';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> tryAutoLogin() async {
    _loading = true;
    notifyListeners();

    final ok = await _api.tryAutoLogin();
    _loading = false;
    notifyListeners();
    return ok;
  }

  Future<String?> getSavedUsername() async {
    return await _api.getSavedUsername();
  }

  Future<String?> getSavedPassword() async {
    return await _api.getSavedPassword();
  }

  void logout() {
    _api.logout();
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
