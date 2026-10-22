import 'package:flutter/foundation.dart';
import '../models/referral_payload.dart';
import '../models/user.dart';
import 'api_client.dart';

class ProfileService {
  ApiClient get _api => ApiClient.instance;

  Map<String, dynamic> _unwrapBody(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return body;
  }

  Future<User?> getProfile() async {
    try {
      final data = await _api.get('/user/profile');
      return User.fromJson(_unwrapBody(jsonMap(data)));
    } catch (e) {
      debugPrint("Error obteniendo perfil: $e");
      return null;
    }
  }

  Future<ReferralPayload?> getReferralPayload() async {
    try {
      final data = await _api.get('/user/referral');
      return ReferralPayload.fromJson(_unwrapBody(jsonMap(data)));
    } catch (e) {
      debugPrint('Error obteniendo referido: $e');
      return null;
    }
  }

  Future<bool> updateProfile(String name, String email) async {
    try {
      await _api.put('/user/profile', body: {'name': name, 'email': email});
      return true;
    } catch (e) {
      debugPrint("Error actualizando perfil: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> updatePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final data = await _api.put(
        '/user/profile/password',
        body: {
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        },
      );
      return {
        'success': true,
        'message': apiMessage(data) ?? 'Contraseña actualizada',
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint("Error actualizando contraseña: $e");
      return {'success': false, 'message': 'Error de conexión'};
    }
  }

  Future<bool> deleteAccount(String password) async {
    try {
      await _api.delete('/user/profile', body: {'password': password});
      return true;
    } catch (e) {
      debugPrint("Error eliminando cuenta: $e");
      return false;
    }
  }
}
