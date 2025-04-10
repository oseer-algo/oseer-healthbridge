// File path: lib/utils/token_debug_tool.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../utils/constants.dart';

/// A debug tool to help diagnose API connection issues
class TokenDebugTool {
  static Future<Map<String, dynamic>> testTokenGeneration(
      String userId, String deviceId, String deviceType) async {
    OseerLogger.info('🔍 DEBUG: Testing token generation API');

    try {
      // Prepare the payload
      final payload = {
        'userId': userId,
        'deviceId': deviceId,
        'deviceType': deviceType
      };

      // Construct the URL
      final uri = Uri.parse('${OseerConstants.apiBaseUrl}/token/generate');

      // Log the request
      OseerLogger.info('🔍 DEBUG: Sending POST to $uri');
      OseerLogger.info('🔍 DEBUG: Payload: $payload');

      // Send the request using http package directly (not Dio)
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // Log the response
      OseerLogger.info('🔍 DEBUG: Response status: ${response.statusCode}');
      OseerLogger.info('🔍 DEBUG: Response body: ${response.body}');

      // Parse and return the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server returned ${response.statusCode}',
          'details': response.body
        };
      }
    } catch (e) {
      OseerLogger.error('🔍 DEBUG: Error testing token generation', e);
      return {
        'success': false,
        'error': 'Network error',
        'details': e.toString()
      };
    }
  }

  static Future<Map<String, dynamic>> testTokenValidation(String token) async {
    OseerLogger.info('🔍 DEBUG: Testing token validation API');

    try {
      // Prepare the payload - ONLY token as expected by server
      final payload = {'token': token};

      // Construct the URL
      final uri = Uri.parse('${OseerConstants.apiBaseUrl}/token/validate');

      // Log the request
      OseerLogger.info('🔍 DEBUG: Sending POST to $uri');
      OseerLogger.info('🔍 DEBUG: Payload: $payload');

      // Send the request using http package directly (not Dio)
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // Log the response
      OseerLogger.info('🔍 DEBUG: Response status: ${response.statusCode}');
      OseerLogger.info('🔍 DEBUG: Response body: ${response.body}');

      // Parse and return the response
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'valid': false,
          'error': 'Server returned ${response.statusCode}',
          'details': response.body
        };
      }
    } catch (e) {
      OseerLogger.error('🔍 DEBUG: Error testing token validation', e);
      return {
        'valid': false,
        'error': 'Network error',
        'details': e.toString()
      };
    }
  }

  static Future<void> showDebugDialog(BuildContext context) async {
    final tokenController = TextEditingController();
    final userIdController = TextEditingController();
    final deviceIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Debug Tool'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  hintText: 'Enter user ID for testing',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'Enter device ID for testing',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  hintText: 'Enter token for validation testing',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (userIdController.text.isNotEmpty &&
                      deviceIdController.text.isNotEmpty) {
                    final result = await testTokenGeneration(
                      userIdController.text,
                      deviceIdController.text,
                      'android',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Result: ${result.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Test Token Generation'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  if (tokenController.text.isNotEmpty) {
                    final result =
                        await testTokenValidation(tokenController.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Result: ${result.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Test Token Validation'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
