// lib/services/biometric_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../services/logger_service.dart';
import '../services/secure_storage_service.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _secureStorage;

  // Storage keys
  static const String biometricEnabledKey = 'oseer_biometric_enabled';
  static const String biometricAuthTokenKey = 'oseer_biometric_auth_token';
  static const String biometricUserIdKey = 'oseer_biometric_user_id';
  static const String biometricUserEmailKey = 'oseer_biometric_user_email';

  BiometricService({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  // Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (e) {
      OseerLogger.error('Error checking biometric availability', e);
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      OseerLogger.error('Error getting available biometrics', e);
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        OseerLogger.error('Biometric authentication not available', e);
      } else if (e.code == auth_error.notEnrolled) {
        OseerLogger.error('No biometrics enrolled', e);
      } else {
        OseerLogger.error('Biometric authentication error', e);
      }
      return false;
    }
  }

  // Save credentials for biometric login
  Future<bool> enableBiometricLogin({
    required String authToken,
    required String userId,
    required String userEmail,
  }) async {
    try {
      // First verify biometric to ensure device security
      final authenticated =
          await authenticate('Verify your identity to enable biometric login');

      if (!authenticated) {
        OseerLogger.info('User cancelled biometric enrollment');
        return false;
      }

      // Save auth data securely
      await _secureStorage.write(biometricAuthTokenKey, authToken);
      await _secureStorage.write(biometricUserIdKey, userId);
      await _secureStorage.write(biometricUserEmailKey, userEmail);

      // Mark biometric login as enabled
      await _secureStorage.write(biometricEnabledKey, 'true');

      OseerLogger.info('Biometric login enabled for user: $userId');
      return true;
    } catch (e) {
      OseerLogger.error('Error enabling biometric login', e);
      return false;
    }
  }

  // Check if biometric login is enabled
  Future<bool> isBiometricLoginEnabled() async {
    try {
      final value = await _secureStorage.read(biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      OseerLogger.error('Error checking if biometric login is enabled', e);
      return false;
    }
  }

  // Get saved auth credentials after successful biometric auth
  Future<Map<String, String?>?> getAuthCredentials() async {
    try {
      final authenticated =
          await authenticate('Verify your identity to log in');

      if (!authenticated) {
        OseerLogger.info('Biometric authentication cancelled by user');
        return null;
      }

      final token = await _secureStorage.read(biometricAuthTokenKey);
      final userId = await _secureStorage.read(biometricUserIdKey);
      final userEmail = await _secureStorage.read(biometricUserEmailKey);

      if (token == null) {
        OseerLogger.warning('No auth token found for biometric login');
        return null;
      }

      return {
        'token': token,
        'userId': userId,
        'userEmail': userEmail,
      };
    } catch (e) {
      OseerLogger.error('Error getting auth credentials with biometrics', e);
      return null;
    }
  }

  // Disable biometric login
  Future<bool> disableBiometricLogin() async {
    try {
      await _secureStorage.delete(biometricEnabledKey);
      await _secureStorage.delete(biometricAuthTokenKey);
      await _secureStorage.delete(biometricUserIdKey);
      await _secureStorage.delete(biometricUserEmailKey);

      OseerLogger.info('Biometric login disabled');
      return true;
    } catch (e) {
      OseerLogger.error('Error disabling biometric login', e);
      return false;
    }
  }
}
