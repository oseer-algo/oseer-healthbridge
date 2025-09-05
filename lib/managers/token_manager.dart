// lib/managers/token_manager.dart (NEW, SIMPLIFIED VERSION)

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';

/// Manages the short-lived HANDOFF token used to connect to the web app.
/// It does NOT manage the primary Supabase authentication token.
class TokenManager {
  final SharedPreferences _prefs;

  // Internal state for the handoff token
  String? _cachedHandoffToken;

  TokenManager({required SharedPreferences prefs}) : _prefs = prefs {
    OseerLogger.debug('TokenManager initialized.');
    _initializeHandoffTokenState();
  }

  /// Load the handoff token from storage on startup.
  void _initializeHandoffTokenState() {
    _cachedHandoffToken = _prefs.getString(OseerConstants.keyHandoffToken);
    if (_cachedHandoffToken != null) {
      OseerLogger.debug('Loaded cached handoff token.');
    }
  }

  /// Stores a new handoff token.
  Future<void> setHandoffToken(String token) async {
    _cachedHandoffToken = token;
    await _prefs.setString(OseerConstants.keyHandoffToken, token);
    OseerLogger.info('Stored new handoff token.');
  }

  /// Retrieves the current handoff token.
  String? getHandoffToken() {
    return _cachedHandoffToken;
  }

  /// Clears the handoff token after it's been used.
  Future<void> clearHandoffToken() async {
    _cachedHandoffToken = null;
    await _prefs.remove(OseerConstants.keyHandoffToken);
    OseerLogger.info('Cleared used handoff token.');
  }

  void dispose() {
    OseerLogger.debug('TokenManager disposed.');
  }
}
