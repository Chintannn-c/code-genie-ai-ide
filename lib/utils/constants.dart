import 'package:flutter/material.dart';

/// App-wide constants.
class AppConstants {
  // Supported programming languages
  static const List<String> languages = [
    'python',
    'javascript',
    'typescript',
    'java',
    'c++',
    'c',
    'c#',
    'dart',
    'go',
    'rust',
    'swift',
    'kotlin',
    'ruby',
    'php',
    'sql',
    'html',
    'css',
    'shell',
    'r',
    'matlab',
  ];

  // Mode options
  static const List<Map<String, dynamic>> modes = [
    {'key': 'generate', 'label': 'Generate', 'icon': Icons.auto_fix_high},
    {'key': 'debug', 'label': 'Debug', 'icon': Icons.bug_report},
    {'key': 'explain', 'label': 'Explain', 'icon': Icons.school},
  ];

  // Default user ID (no auth)
  static const String defaultUserId = 'default_user';
}
