import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/app_file.dart';
import 'package:file_picker/file_picker.dart';

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);
  @override
  String toString() => message;
}

class InterceptingClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SessionExpiredException('Session expired (${response.statusCode})');
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
  }
}

/// HTTP API service for non-streaming requests.
class ApiService {
  final http.Client _client = InterceptingClient();

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: queryParams);
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true', 
      'ngrok-skip-browser-warning': 'true', // Added for Ngrok
      'X-Platform': kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Desktop')),
      'X-Device-Name': kIsWeb ? 'Browser' : (defaultTargetPlatform == TargetPlatform.macOS ? 'macOS Desktop' : (defaultTargetPlatform == TargetPlatform.windows ? 'Windows Desktop' : (defaultTargetPlatform == TargetPlatform.linux ? 'Linux Desktop' : 'Native Client'))),
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(_uri(ApiConfig.health));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generate code (non-streaming)
  Future<Map<String, dynamic>> generateCode({
    required String userId,
    required String prompt,
    required String language,
    String? chatId,
    List<String>? fileIds,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.generate),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'chat_id': chatId,
        'prompt': prompt,
        'language': language,
        if (fileIds != null && fileIds.isNotEmpty) 'file_ids': fileIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Generate failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Debug code (non-streaming)
  Future<Map<String, dynamic>> debugCode({
    required String userId,
    required String code,
    required String error,
    required String language,
    String? chatId,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.debug),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'chat_id': chatId,
        'code': code,
        'error': error,
        'language': language,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Debug failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Explain code (non-streaming)
  Future<Map<String, dynamic>> explainCode({
    required String userId,
    required String code,
    required String language,
    String? chatId,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.explain),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'chat_id': chatId,
        'code': code,
        'language': language,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Explain failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Parallel AI Orchestration (Queries multiple models simultaneously)
  Future<Map<String, dynamic>> orchestrate({
    required String userId,
    required String prompt,
    String? language,
    String? chatId,
    String provider = 'gemini',
    String? modelName,
    List<String>? fileIds,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.orchestrate),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'chat_id': chatId,
        'prompt': prompt,
        'language': language ?? 'python',
        'provider': provider,
        'model_name': modelName,
        if (fileIds != null && fileIds.isNotEmpty) 'file_ids': fileIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Orchestration failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Get user's chat list (paginated)
  Future<List<Chat>> getChats(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      _uri(ApiConfig.chats(userId), {'page': '$page', 'limit': '$limit'}),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load chats: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['chats'] as List).map((c) => Chat.fromJson(c)).toList();
  }

  /// Get messages for a chat (paginated)
  Future<List<Message>> getMessages(
    String chatId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      _uri(ApiConfig.messages(chatId), {'page': '$page', 'limit': '$limit'}),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load messages: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['messages'] as List).map((m) => Message.fromJson(m)).toList();
  }

  /// Upload multiple files
  Future<List<AppFile>> uploadFiles({
    required String userId,
    required List<PlatformFile> files,
  }) async {
    var request = http.MultipartRequest('POST', _uri(ApiConfig.upload));

    // ADDED: Set headers for authentication and proxy bypass
    request.headers.addAll({
      if (_token != null) 'Authorization': 'Bearer $_token',
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
    });

    request.fields['user_id'] = userId;

    for (var file in files) {
      if (kIsWeb) {
        // FIX: On Web, we MUST use bytes as path is null
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ));
        }
      } else {
        // On Native, path is generally preferred
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('files', file.path!));
        } else if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ));
        }
      }
    }

    if (request.files.isEmpty) {
      throw Exception('No valid files to upload');
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as List;
    return data.map((f) => AppFile.fromJson(f)).toList();
  }

  /// Analyze a file
  Future<Map<String, dynamic>> analyzeFile({
    required String userId,
    required String fileId,
    String? chatId,
    String type = 'summary',
    String difficulty = 'beginner',
    String provider = 'gemini',
    String? modelName,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.analyzeFile, chatId != null ? {'chat_id': chatId} : null),
      headers: _headers,
      body: jsonEncode({
        'file_id': fileId,
        'analysis_type': type,
        'difficulty': difficulty,
        'provider': provider,
        'model_name': modelName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Analysis failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Debug a file
  Future<Map<String, dynamic>> debugFile({
    required String userId,
    required String fileId,
    required String error,
    String? chatId,
    String difficulty = 'beginner',
    String provider = 'gemini',
    String? modelName,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.debugFile, chatId != null ? {'chat_id': chatId} : null),
      headers: _headers,
      body: jsonEncode({
        'file_id': fileId,
        'error': error,
        'difficulty': difficulty,
        'provider': provider,
        'model_name': modelName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('File debug failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Get list of uploaded files for a user
  Future<List<AppFile>> getUserFiles(String userId) async {
    final response = await _client.get(
      _uri(ApiConfig.userFiles(userId)),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load user files: ${response.body}');
    }

    final data = jsonDecode(response.body) as List;
    return data.map((f) => AppFile.fromJson(f)).toList();
  }

  /// Generate a patch
  Future<Map<String, dynamic>> generatePatch(String fileId, String issue) async {
    final response = await _client.post(
      _uri(ApiConfig.patch),
      headers: _headers,
      body: jsonEncode({'file_id': fileId, 'issue': issue}),
    );

    if (response.statusCode != 200) {
      throw Exception('Patch generation failed: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Create a new chat
  Future<String> createChat(String userId, String title) async {
    final response = await _client.post(
      _uri(ApiConfig.chats(userId)),
      headers: { ..._headers, 'Bypass-Tunnel-Reminder': 'true' },
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create chat: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['chat_id'];
  }

  /// Save a message to a chat
  Future<String> saveMessage({
    required String chatId,
    required String role,
    required String content,
    String? type,
    String? language,
    String? fileId,
    bool? isImage,
  }) async {
    final response = await _client.post(
      _uri(ApiConfig.messages(chatId)),
      headers: _headers,
      body: jsonEncode({
        'role': role,
        'content': content,
        'type': type ?? 'generate',
        'language': language ?? 'text',
        'file_id': fileId,
        'is_image': isImage ?? false,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save message: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['message_id'];
  }

  /// Delete a chat session
  Future<bool> deleteChat(String chatId) async {
    final response = await _client.delete(
      _uri(ApiConfig.chat(chatId)),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete chat: ${response.body}');
    }

    return true;
  }

  /// Terminate active AI generation for a chat session (memory leak prevention & cross-device sync).
  Future<Map<String, dynamic>> stopGeneration(String chatId) async {
    final response = await _client.post(
      _uri('/api/chat/stop'),
      headers: _headers,
      body: jsonEncode({'chat_id': chatId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to stop generation: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Get metadata for a specific file
  Future<AppFile> getFileMetadata(String fileId) async {
    final response = await _client.get(
      _uri('/api/file-metadata/$fileId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load file metadata: ${response.body}');
    }

    return AppFile.fromJson(jsonDecode(response.body));
  }

  /// Download the raw string contents of an uploaded file
  Future<String> downloadFileContent(String fileId) async {
    final response = await _client.get(
      _uri('/api/file/$fileId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download file content: ${response.body}');
    }

    return response.body;
  }

  void dispose() {
    _client.close();
  }
}
