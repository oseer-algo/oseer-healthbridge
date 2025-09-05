// lib/services/secure_storage_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/logger_service.dart';

/// Service for securely storing sensitive information
class SecureStorageService {
  final FlutterSecureStorage _storage;

  // Storage options with iOS options for extra security
  static const _options = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    synchronizable: false,
  );

  // Constructor with dependency injection
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(iOptions: _options);

  /// Write string value
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      OseerLogger.error('Error writing to secure storage: key=$key', e);
      rethrow;
    }
  }

  /// Write JSON object
  Future<void> writeJson(String key, Map<String, dynamic> json) async {
    try {
      final jsonString = jsonEncode(json);
      await _storage.write(key: key, value: jsonString);
    } catch (e) {
      OseerLogger.error('Error writing JSON to secure storage: key=$key', e);
      rethrow;
    }
  }

  /// Read string value
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      OseerLogger.error('Error reading from secure storage: key=$key', e);
      return null;
    }
  }

  /// Read JSON object
  Future<Map<String, dynamic>?> readJson(String key) async {
    try {
      final jsonString = await _storage.read(key: key);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      OseerLogger.error('Error reading JSON from secure storage: key=$key', e);
      return null;
    }
  }

  /// Delete a value
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      OseerLogger.error('Error deleting from secure storage: key=$key', e);
      rethrow;
    }
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      OseerLogger.error('Error checking key in secure storage: key=$key', e);
      return false;
    }
  }

  /// Delete all stored values
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      OseerLogger.error('Error deleting all from secure storage', e);
      rethrow;
    }
  }

  /// Get all stored keys
  Future<List<String>> getAllKeys() async {
    try {
      final allValues = await _storage.readAll();
      return allValues.keys.toList();
    } catch (e) {
      OseerLogger.error('Error getting all keys from secure storage', e);
      return [];
    }
  }
}
