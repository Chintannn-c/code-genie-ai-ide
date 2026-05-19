import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/stream_chunk.dart';

/// SSE streaming service for real-time AI responses.
class StreamService {
  http.Client? _client;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  /// Common logic for handling SSE streams from any endpoint
  Stream<StreamChunk> _postStream(String path, Map<String, dynamic> body) async* {
    // Close existing client if any
    cancel();
    _client = http.Client();

    try {
      final request = http.Request('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Bypass-Tunnel-Reminder': 'true',
        'ngrok-skip-browser-warning': 'true',
      };
      
      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }
      
      request.headers.addAll(headers);
      request.body = jsonEncode(body);

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        yield StreamChunk.error('Server error: ${response.statusCode}');
        return;
      }

      String buffer = '';
      // Use utf8.decoder.bind to handle multi-byte characters (emojis) correctly across chunks
      final stream = response.stream.transform(utf8.decoder);

      await for (final chunkStr in stream) {
        buffer += chunkStr;

        // Split buffer by lines and process
        final lines = buffer.split(RegExp(r'\r?\n'));
        
        // Keep the last partial line in the buffer
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.startsWith('data:')) {
            final data = trimmedLine.substring(5).trim();
            if (data.isNotEmpty) {
              if (data == '[DONE]') {
                return;
              }
              final chunk = StreamChunk.fromSSEData(data);
              if (chunk.error != null) {
                yield StreamChunk.error(chunk.error!);
                return;
              }
              yield chunk;
              if (chunk.done) return;
            }
          }
        }
      }
    } catch (e) {
      // Don't yield error if it was manually cancelled
      if (_client != null) {
        yield StreamChunk.error('Connection error: $e');
      }
    } finally {
      // Optional: keep client open for the duration of the stream then close
      // but here we close on manual cancel or completion
    }
  }

  Stream<StreamChunk> streamResponse({
    required String userId,
    required String type,
    required String language,
    String prompt = '',
    String code = '',
    String error = '',
    String? chatId,
    String difficulty = 'beginner',
    String provider = 'gemini',
    String? modelName,
    List<String>? fileIds,
    double? temperature,
    int? maxTokens,
    Map<String, String>? customApiKeys,
  }) {
    return _postStream(ApiConfig.stream, {
      'user_id': userId,
      'chat_id': chatId,
      'prompt': prompt,
      'code': code,
      'error': error,
      'language': language,
      'type': type,
      'difficulty': difficulty,
      'provider': provider,
      if (modelName != null) 'model_name': modelName,
      if (fileIds != null && fileIds.isNotEmpty) 'file_ids': fileIds,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (customApiKeys != null && customApiKeys.isNotEmpty) 'custom_api_keys': customApiKeys,
    });
  }

  /// Stream file analysis
  Stream<StreamChunk> streamFileAnalysis({
    required String userId,
    required String fileId,
    String type = 'summary',
    String? chatId,
    String difficulty = 'beginner',
  }) {
    return _postStream(ApiConfig.streamAnalyzeFile, {
      'user_id': userId,
      'file_id': fileId,
      'analysis_type': type,
      'chat_id': chatId,
      'difficulty': difficulty,
    });
  }

  /// Stream file debugging
  Stream<StreamChunk> streamFileDebug({
    required String userId,
    required String fileId,
    required String error,
    String? chatId,
    String difficulty = 'beginner',
  }) {
    return _postStream(ApiConfig.streamDebugFile, {
      'user_id': userId,
      'file_id': fileId,
      'error': error,
      'chat_id': chatId,
      'difficulty': difficulty,
    });
  }

  /// Cancel the current stream
  void cancel() {
    _client?.close();
    _client = null;
  }

  void dispose() {
    cancel();
  }
}
