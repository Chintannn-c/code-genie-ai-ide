/*
 * FIXES APPLIED: 2026-05-06
 * Bug #1 — RepaintBoundary + SizeTransition — line ~170 (in ChatScreen)
 * Bug #2 — compute() isolate for regex — line ~692
 * Bug #3 — CONCURRENCY FIX: Added cancellation guard to setUserId — line ~40
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/app_file.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import '../services/stream_service.dart';
import '../services/websocket_service.dart';

/// Top-level function for isolate-safe regex parsing.
List<Map<String, String>> _parseCodeBlocks(String content) {
  final regExp = RegExp(r'```(\w+)?\n([\s\S]*?)```');
  return regExp
      .allMatches(content)
      .map(
        (m) => {'language': m.group(1) ?? 'python', 'code': m.group(2) ?? ''},
      )
      .toList();
}

/// Main state management for chat functionality.
class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StreamService _streamService = StreamService();
  final WebSocketService _wsService = WebSocketService();

  // State
  List<Chat> _chats = [];
  List<Message> _messages = [];
  String? _currentChatId;
  String? _userId;
  bool _isStreaming = false;
  bool _isOrchestrating = false;
  bool _isLoading = false;
  String _selectedDifficulty = 'beginner';
  String _selectedLanguage = 'python';
  String _selectedMode = 'generate';
  String _latestCode = '';
  String _latestLanguage = 'python';
  String _selectedProvider = 'gemini';
  String? _selectedModel;
  String _activityLabel = 'Ready';
  StreamSubscription? _wsSubscription;
  bool _isEditorMode = false;
  String? _errorMessage;
  StreamSubscription? _streamSubscription;

  // Context awareness & heartbeat watchdog states
  String? _currentContextStatus;
  Timer? _heartbeatTimer;
  bool _isStalled = false;

  // CONCURRENCY FIX: Token to cancel delayed initialization on logout
  Timer? _bootTimer;

  final Map<String, List<Map<String, String>>> _codeCache = {};

  void setUserId(String? id, String? token) {
    if (_userId == id) return;

    // CONCURRENCY FIX: Cancel any pending boot timer to prevent ghost subscriptions
    _bootTimer?.cancel();
    _bootTimer = null;

    // HEARTBEAT & STREAM FIX: Cleanly abort and release active timers & stream networks
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isStalled = false;
    _currentContextStatus = null;
    _isStreaming = false;
    _isOrchestrating = false;
    _streamSubscription?.cancel();
    _streamSubscription = null;

    _userId = id;
    _apiService.setToken(token);
    _streamService.setToken(token);

    _chats = [];
    _messages = [];
    _currentChatId = null;
    _errorMessage = null;
    _codeCache.clear();

    _wsSubscription?.cancel();
    _wsSubscription = null;

    if (id != null) {
      // CONCURRENCY FIX: Assign to timer for explicit lifecycle management
      _bootTimer = Timer(const Duration(milliseconds: 100), () {
        if (_userId == id) {
          _wsService.connect(id, token);
          _wsSubscription = _wsService.stream.listen(
            (event) => _handleSyncEvent(event),
          );
        }
      });
      loadChats();
    } else {
      _wsService.disconnect();
      notifyListeners();
    }
  }

  void _handleSyncEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'chat_updated' || type == 'chat_created') {
      loadChats();
    } else if (type == 'message_received') {
      if (_currentChatId == event['chat_id']) {
        loadMessages(_currentChatId!);
      }
      loadChats();
    } else if (type == 'chat_deleted') {
      if (_currentChatId == event['chat_id']) {
        _currentChatId = null;
        _messages = [];
      }
      loadChats();
    }
  }

  // Getters
  List<Chat> get chats => _chats;

  Chat? get currentChat {
    if (_currentChatId == null) return null;
    for (var chat in _chats) {
      if (chat.chatId == _currentChatId) return chat;
    }
    return null;
  }

  List<Chat> get filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    return _chats
        .where(
          (chat) =>
              chat.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Message> get messages => _messages;
  String? get currentChatId => _currentChatId;
  bool get isStreaming => _isStreaming;
  bool get isOrchestrating => _isOrchestrating;
  bool get isLoading => _isLoading;
  String get selectedLanguage => _selectedLanguage;
  String get selectedMode => _selectedMode;
  String? get errorMessage => _errorMessage;
  String get selectedDifficulty => _selectedDifficulty;
  String get latestCode => _latestCode;
  String get latestLanguage => _latestLanguage;
  String get selectedProvider => _selectedProvider;
  String? get selectedModel => _selectedModel;
  String get activityLabel => _activityLabel;
  bool get isEditorMode => _isEditorMode;
  String? get currentContextStatus => _currentContextStatus;
  bool get isStalled => _isStalled;

  void toggleEditorMode() {
    _isEditorMode = !_isEditorMode;
    if (_isEditorMode) {
      _selectedMode = 'generate';
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    await loadChats();
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  void setDifficulty(String difficulty) {
    _selectedDifficulty = difficulty;
    notifyListeners();
  }

  void setMode(String mode) {
    _selectedMode = mode;
    notifyListeners();
  }

  void setProvider(String provider) {
    _selectedProvider = provider;
    _selectedModel = null;
    notifyListeners();
  }

  void setModel(String? model) {
    _selectedModel = model;
    notifyListeners();
  }

  void stopStreaming() {
    stopGenerating();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadChats() async {
    if (_userId == null) return;
    
    // 1. Optimistic Local Hydration: Load cached conversations in <10ms
    try {
      final box = await Hive.openBox('cached_chats_box_$_userId');
      final cachedJson = box.get('chats_list');
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as List;
        _chats = decoded.map((c) => Chat.fromJson(c)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error reading chats cache: $e');
    }

    // 2. Background Revalidation: Fetch fresh PostgreSQL data silently
    try {
      final freshChats = await _apiService.getChats(_userId!);
      _chats = freshChats;
      notifyListeners();

      // 3. Keep Cache database updated in the background
      final box = await Hive.openBox('cached_chats_box_$_userId');
      final encodable = freshChats.map((c) => c.toJson()).toList();
      await box.put('chats_list', jsonEncode(encodable));
    } catch (e) {
      _errorMessage = 'Failed to load chats: $e';
      notifyListeners();
    }
  }

  Future<List<Chat>> getChatsFromApi(String userId, {int page = 1, int limit = 20}) async {
    return await _apiService.getChats(userId, page: page, limit: limit);
  }

  Future<void> appendChats(List<Chat> newChats) async {
    final existingIds = _chats.map((c) => c.chatId).toSet();
    for (var chat in newChats) {
      if (!existingIds.contains(chat.chatId)) {
        _chats.add(chat);
      }
    }
    notifyListeners();

    try {
      final box = await Hive.openBox('cached_chats_box_$_userId');
      final encodable = _chats.map((c) => c.toJson()).toList();
      await box.put('chats_list', jsonEncode(encodable));
    } catch (e) {
      debugPrint('⚠️ Error updating cache: $e');
    }
  }

  Future<void> loadMessages(String chatId) async {
    try {
      _messages = await _apiService.getMessages(chatId);
      await _updateLatestCode();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load messages: $e';
      notifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    final previousChats = List<Chat>.from(_chats);

    // 1. Optimistic UI: Instantly remove chat from frontend state
    _chats.removeWhere((c) => c.chatId == chatId);
    if (_currentChatId == chatId) {
      _currentChatId = null;
      _messages = [];
    }
    notifyListeners();

    try {
      final success = await _apiService.deleteChat(chatId);
      if (!success) {
        // Rollback state if api reports failure
        _chats = previousChats;
        _errorMessage = 'Server refused deletion. Rolling back state...';
        notifyListeners();
      } else {
        // Silently update cache box
        final box = await Hive.openBox('cached_chats_box_$_userId');
        final encodable = _chats.map((c) => c.toJson()).toList();
        await box.put('chats_list', jsonEncode(encodable));
      }
    } catch (e) {
      // Rollback state on connection or parsing failure
      _chats = previousChats;
      _errorMessage = 'Connection failure: $e. Reverted optimistic delete.';
      notifyListeners();
    }
  }

  Future<void> openChat(String chatId) async {
    _currentChatId = chatId;
    _messages = []; // Clear instantly to enable immediate UI switch
    _isLoading = true;
    notifyListeners();
    await loadMessages(chatId);
    _isLoading = false;
    notifyListeners();
  }

  void newChat() {
    _currentChatId = null;
    _messages = [];
    _errorMessage = null;
    notifyListeners();
  }

  bool _useParallelOrchestration = false;
  bool _isMissionMode = false;
  bool _isWebMode = false;

  bool get useParallelOrchestration => _useParallelOrchestration;
  bool get isMissionMode => _isMissionMode;
  bool get isWebMode => _isWebMode;

  void toggleParallelOrchestration() {
    _useParallelOrchestration = !_useParallelOrchestration;
    if (_useParallelOrchestration) {
      _isMissionMode = false;
    }
    notifyListeners();
  }

  void toggleMissionMode() {
    _isMissionMode = !_isMissionMode;
    if (_isMissionMode) {
      _useParallelOrchestration = false;
    }
    notifyListeners();
  }

  void setWebMode(bool active) {
    _isWebMode = active;
    notifyListeners();
  }

  void toggleWebMode() {
    _isWebMode = !_isWebMode;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String prompt,
    String code = '',
    String error = '',
    double? temperature,
    int? maxTokens,
    Map<String, String>? customApiKeys,
  }) async {
    if (_isStreaming || _isLoading) return;
    _errorMessage = null;

    final userContent = _selectedMode == 'generate'
        ? prompt
        : _selectedMode == 'debug'
        ? '**Code:**\n```$_selectedLanguage\n$code\n```\n\n**Error:** $error'
        : '```$_selectedLanguage\n$code\n```';

    final userMessage = Message.userMessage(
      content: userContent,
      type: _selectedMode,
      language: _selectedLanguage,
    );

    _messages.add(userMessage);
    notifyListeners();

    try {
      final fileIds = _selectedFiles.map((f) => f.fileId).toList();
      if (_useParallelOrchestration) {
        await _orchestrateMessage(prompt, code, error, fileIds: fileIds);
      } else {
        await _streamMessage(
          prompt,
          code,
          error,
          fileIds: fileIds,
          temperature: temperature,
          maxTokens: maxTokens,
          customApiKeys: customApiKeys,
        );
      }

      // Clear files after successful send
      _selectedFiles = [];
      notifyListeners();
    } catch (e) {
      _activityLabel = 'Ready';
      _isStreaming = false;
      _isOrchestrating = false;
      _messages.add(Message(
        messageId: 'err_${DateTime.now().millisecondsSinceEpoch}',
        role: 'ai',
        content: '⚠️ Code Genie failed to respond. Please check your network connection, API configurations, or model settings and try again.',
        timestamp: DateTime.now(),
        type: _selectedMode,
        language: _selectedLanguage,
      ));
      notifyListeners();
    }
  }

  Future<void> fixCode(String code, String language) async {
    _selectedLanguage = language;
    _selectedMode = 'debug';
    await sendMessage(
      prompt: "Fix this code and explain the changes.",
      code: code,
      error: "Potential issues or bugs found by user.",
    );
  }

  Future<void> optimizeCode(String code, String language) async {
    _selectedLanguage = language;
    _selectedMode = 'generate';
    await sendMessage(
      prompt: "Optimize this code for better performance and readability.",
      code: code,
    );
  }

  Future<void> _orchestrateMessage(
    String prompt,
    String code,
    String error, {
    List<String>? fileIds,
  }) async {
    _isOrchestrating = true;
    _activityLabel = 'Deep solve: coordinating expert agents';
    notifyListeners();
    try {
      final result = await _apiService.orchestrate(
        userId: _userId!,
        chatId: _currentChatId,
        prompt: prompt,
        language: _selectedLanguage,
        fileIds: fileIds,
        provider: _selectedProvider,
        modelName: _selectedModel,
      );
      _currentChatId = result['chat_id'];
      _messages = await _apiService.getMessages(_currentChatId!);
      await _updateLatestCode();
    } finally {
      _isOrchestrating = false;
      _activityLabel = 'Ready';
      notifyListeners();
      loadChats();
    }
  }

  Future<void> _streamMessage(
    String prompt,
    String code,
    String error, {
    List<String>? fileIds,
    double? temperature,
    int? maxTokens,
    Map<String, String>? customApiKeys,
  }) async {
    final aiMessage = Message.aiStreaming(
      type: _selectedMode,
      language: _selectedLanguage,
    );
    _messages.add(aiMessage);
    _isStreaming = true;
    _isStalled = false;
    _currentContextStatus = null;
    _activityLabel =
        'Streaming from ${_providerDisplayName(_selectedProvider)}';
    _resetHeartbeat();
    notifyListeners();
    String fullResponse = '';

    if (fileIds != null && fileIds.isNotEmpty) {
      startDocumentAnalysisStages();
    }

    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      final stream = _streamService.streamResponse(
        userId: _userId!,
        type: _selectedMode,
        language: _selectedLanguage,
        prompt: prompt,
        code: code,
        error: error,
        chatId: _currentChatId,
        difficulty: _selectedDifficulty,
        provider: _selectedProvider,
        modelName: _selectedModel,
        fileIds: fileIds,
        temperature: temperature,
        maxTokens: maxTokens,
        customApiKeys: customApiKeys,
      );

      _streamSubscription = stream
          .timeout(
            const Duration(seconds: 20),
            onTimeout: (sink) {
              _cancelHeartbeat();
              _currentContextStatus = null;
              stopDocumentAnalysisStages();
              final errorText =
                  '⚠️ Code Genie failed to respond. Connection timed out. Please try again.';
              if (_messages.isNotEmpty && _messages.last.role == 'ai') {
                _messages[_messages.length - 1] = _messages.last.copyWith(
                  content: errorText,
                );
              }
              _isStreaming = false;
              _activityLabel = 'Ready';
              notifyListeners();
              sink.close();
            },
          )
          .listen(
            (chunk) async {
              // Parse live context awareness status badges
              if (chunk.status != null && chunk.status!.isNotEmpty) {
                _currentContextStatus = chunk.status;
                _isStalled = false;
                _resetHeartbeat();
                notifyListeners();
                return;
              }

              if (chunk.text.isNotEmpty || chunk.done || chunk.error != null) {
                stopDocumentAnalysisStages();
                _currentContextStatus = null;
                _isStalled = false;
                _resetHeartbeat();
              }

              if (chunk.error != null) {
                _cancelHeartbeat();
                _currentContextStatus = null;
                final errorText = '⚠️ Code Genie failed to respond: ${chunk.error}';
                if (_messages.isNotEmpty && _messages.last.role == 'ai') {
                  _messages[_messages.length - 1] = _messages.last.copyWith(
                    content: errorText,
                  );
                }
                _isStreaming = false;
                _activityLabel = 'Ready';
                notifyListeners();
                return;
              }

              if (chunk.done) {
                _cancelHeartbeat();
                _currentContextStatus = null;
                if (chunk.chatId != null) _currentChatId = chunk.chatId;
                if (chunk.modelName != null && chunk.modelName!.isNotEmpty) {
                  _activityLabel = 'Completed with ${chunk.modelName}';
                }
                if (_messages.isNotEmpty && _messages.last.role == 'ai') {
                  _messages[_messages.length - 1] = _messages.last.copyWith(
                    content: fullResponse,
                    messageId: chunk.messageId,
                    modelName: chunk.modelName,
                  );
                }
                _isStreaming = false;
                _activityLabel = 'Ready';
                await _updateLatestCode();
                notifyListeners();
                loadChats();
                return;
              }

              fullResponse += chunk.text;
              if (_messages.isNotEmpty && _messages.last.role == 'ai') {
                _messages[_messages.length - 1] = _messages.last.copyWith(
                  content: fullResponse,
                );
              }

              if (fullResponse.contains('```') &&
                  fullResponse.endsWith('```')) {
                await _updateLatestCode();
              }

              notifyListeners();
            },
            onError: (e) {
              _cancelHeartbeat();
              _currentContextStatus = null;
              final errorText = '⚠️ Code Genie failed to respond. Connection lost. Please try again.';
              if (_messages.isNotEmpty && _messages.last.role == 'ai') {
                _messages[_messages.length - 1] = _messages.last.copyWith(
                  content: errorText,
                );
              }
              _isStreaming = false;
              _activityLabel = 'Ready';
              notifyListeners();
            },
            onDone: () {
              _cancelHeartbeat();
              _currentContextStatus = null;
              _isStreaming = false;
              _activityLabel = 'Ready';
              notifyListeners();
            },
          );
    } catch (e) {
      _cancelHeartbeat();
      _currentContextStatus = null;
      _errorMessage = 'Failed to send message: $e';
      _isStreaming = false;
      _activityLabel = 'Ready';
      notifyListeners();
    }
  }

  /// Interactive stop action: aborts streaming connections and terminates compute tasks on backend.
  Future<void> stopGenerating() async {
    if (!_isStreaming || _currentChatId == null) return;

    _cancelHeartbeat();
    _currentContextStatus = null;
    stopDocumentAnalysisStages();

    // 1. Instantly abort client-side network request subscription
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamService.cancel();

    _isStreaming = false;
    _activityLabel = 'Ready';
    notifyListeners();

    // 2. Call explicit stop API to cancel backend pipeline
    try {
      await _apiService.stopGeneration(_currentChatId!);
    } catch (e) {
      debugPrint('Failed to send stop signal to backend: $e');
    }

    // 3. Gracefully retrieve and sync the saved partial response from backend database
    await loadMessages(_currentChatId!);
  }

  /// Reset the connection heartbeat watchdog to detect stalled streams
  void _resetHeartbeat() {
    _heartbeatTimer?.cancel();
    if (!_isStreaming) return;
    _heartbeatTimer = Timer(const Duration(seconds: 10), () {
      if (_isStreaming) {
        _isStalled = true;
        notifyListeners();
      }
    });
  }

  /// Cancel and release resources occupied by the connection watchdog
  void _cancelHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isStalled = false;
  }

  String _providerDisplayName(String provider) {
    switch (provider) {
      case 'openrouter':
        return 'OpenRouter';
      case 'groq':
        return 'Groq';
      case 'github':
        return 'GitHub Models';
      case 'mistral':
        return 'Mistral';
      case 'huggingface':
        return 'Hugging Face';
      default:
        return 'Gemini';
    }
  }

  // --- File Logic ---
  List<AppFile> _selectedFiles = [];
  bool _isUploading = false;
  List<AppFile> get selectedFiles => _selectedFiles;
  bool get isUploading => _isUploading;

  String? _documentReadingStage;
  String? get documentReadingStage => _documentReadingStage;
  Timer? _stageTimer;

  void removeFile(String fileId) {
    _selectedFiles.removeWhere((f) => f.fileId == fileId);
    notifyListeners();
  }

  void clearFiles() {
    _selectedFiles = [];
    notifyListeners();
  }

  Future<void> analyzeProject() async {
    if (_selectedFiles.isEmpty) return;
    final fileList = _selectedFiles.map((f) => f.fileName).join(', ');
    final prompt = 'Please analyze this project: $fileList.';
    setLanguage(_selectedFiles.first.language);
    setMode('explain');
    sendMessage(prompt: prompt);
  }

  void startDocumentAnalysisStages() {
    _documentReadingStage = "Preparing context...";
    notifyListeners();
    
    final stages = [
      "Extracting text...",
      "Analyzing document structure...",
      "Understanding context...",
      "Generating embeddings...",
      "Finding key insights...",
      "Preparing intelligent response...",
    ];
    int stageIdx = 0;
    
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (stageIdx < stages.length - 1) {
        stageIdx++;
        _documentReadingStage = stages[stageIdx];
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  void stopDocumentAnalysisStages() {
    _stageTimer?.cancel();
    _stageTimer = null;
    _documentReadingStage = null;
    notifyListeners();
  }

  Future<void> uploadFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    for (var file in files) {
      await _uploadSingleFile(file);
    }

    _isUploading = false;
    notifyListeners();
  }

  Future<void> _uploadSingleFile(PlatformFile file) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final optimisticFile = AppFile(
      fileId: tempId,
      fileName: file.name,
      language: file.extension ?? 'txt',
      size: file.size,
      status: FileUploadStatus.preparing,
      progress: 0.05,
      platformFile: file,
    );

    _selectedFiles.add(optimisticFile);
    notifyListeners();

    await _executeUpload(tempId, file);
  }

  Future<void> _executeUpload(String fileId, PlatformFile file) async {
    int index = _selectedFiles.indexWhere((f) => f.fileId == fileId);
    if (index == -1) return;

    try {
      // 1. Preparing
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.preparing,
        progress: 0.1,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Encrypting
      if (index >= _selectedFiles.length || _selectedFiles[index].status == FileUploadStatus.paused) return;
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.encrypting,
        progress: 0.2,
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. Uploading (Simulating chunked speed transfer indicators)
      if (index >= _selectedFiles.length || _selectedFiles[index].status == FileUploadStatus.paused) return;
      
      double progressVal = 0.2;
      final startTime = DateTime.now();
      
      while (progressVal < 0.8) {
        if (index >= _selectedFiles.length) return;
        if (_selectedFiles[index].status == FileUploadStatus.paused) return;
        
        progressVal += 0.15;
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final speedKb = elapsed > 0 ? (file.size * progressVal) / elapsed : 180.0;
        final remainingBytes = file.size * (1.0 - progressVal);
        final remainingSec = speedKb > 0 ? (remainingBytes / 1024) / speedKb : 2.0;

        _selectedFiles[index] = _selectedFiles[index].copyWith(
          status: FileUploadStatus.uploading,
          progress: progressVal,
          uploadSpeed: '${(speedKb / 10).toStringAsFixed(1)} KB/s',
          timeRemaining: '${remainingSec.toStringAsFixed(0)}s left',
        );
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 250));
      }

      // 4. Processing
      if (index >= _selectedFiles.length || _selectedFiles[index].status == FileUploadStatus.paused) return;
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.processing,
        progress: 0.85,
        uploadSpeed: '',
        timeRemaining: '',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      // 5. Analyzing
      if (index >= _selectedFiles.length || _selectedFiles[index].status == FileUploadStatus.paused) return;
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.analyzing,
        progress: 0.92,
      );
      notifyListeners();

      // Trigger actual network upload API
      final uploadedList = await _apiService.uploadFiles(
        userId: _userId!,
        files: [file],
      );

      if (uploadedList.isEmpty) {
        throw Exception('Server rejected the attachment file content.');
      }

      // 6. Ready for AI
      if (index >= _selectedFiles.length) return;
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        fileId: uploadedList.first.fileId,
        language: uploadedList.first.language,
        status: FileUploadStatus.ready,
        progress: 1.0,
      );
      notifyListeners();

    } catch (e) {
      if (index < _selectedFiles.length && index != -1) {
        _selectedFiles[index] = _selectedFiles[index].copyWith(
          status: FileUploadStatus.failed,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
          progress: 0.0,
        );
        notifyListeners();
      }
    }
  }

  void pauseUpload(String fileId) {
    int index = _selectedFiles.indexWhere((f) => f.fileId == fileId);
    if (index != -1) {
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.paused,
      );
      notifyListeners();
    }
  }

  void resumeUpload(String fileId) {
    int index = _selectedFiles.indexWhere((f) => f.fileId == fileId);
    if (index != -1) {
      _selectedFiles[index] = _selectedFiles[index].copyWith(
        status: FileUploadStatus.uploading,
      );
      notifyListeners();
      _executeUpload(fileId, _selectedFiles[index].platformFile!);
    }
  }

  void retryUpload(String fileId) {
    int index = _selectedFiles.indexWhere((f) => f.fileId == fileId);
    if (index != -1) {
      final file = _selectedFiles[index].platformFile;
      if (file != null) {
        _executeUpload(fileId, file);
      }
    }
  }

  Future<void> analyzeFile(String fileId, {String type = 'summary'}) async {
    if (_isStreaming) return;
    await _streamSubscription?.cancel();
    _isStreaming = true;
    _activityLabel = 'Analyzing file context';
    _isLoading = true;
    notifyListeners();
    final aiMessage = Message.aiStreaming(
      type: 'file_analysis',
      language: _selectedLanguage,
    );
    _messages.add(aiMessage);
    _isLoading = false;
    notifyListeners();
    String fullResponse = '';
    try {
      final stream = _streamService.streamFileAnalysis(
        userId: _userId!,
        fileId: fileId,
        chatId: _currentChatId,
        type: type,
        difficulty: _selectedDifficulty,
      );
      _streamSubscription = stream.listen((chunk) async {
        if (chunk.error != null) {
          _errorMessage = chunk.error;
          _isStreaming = false;
          _activityLabel = 'Ready';
          notifyListeners();
          return;
        }
        if (chunk.done) {
          if (chunk.chatId != null) _currentChatId = chunk.chatId;
          if (_messages.isNotEmpty && _messages.last.role == 'ai') {
            _messages[_messages.length - 1] = _messages.last.copyWith(
              content: fullResponse,
              messageId: chunk.messageId,
            );
          }
          _isStreaming = false;
          _activityLabel = 'Ready';
          await _updateLatestCode();
          notifyListeners();
          loadChats();
          return;
        }
        fullResponse += chunk.text;
        if (_messages.isNotEmpty && _messages.last.role == 'ai') {
          _messages[_messages.length - 1] = _messages.last.copyWith(
            content: fullResponse,
          );
        }
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = 'Analysis failed: $e';
      _isStreaming = false;
      _activityLabel = 'Ready';
      notifyListeners();
    }
  }

  Future<void> debugFile(String fileId, String error) async {
    if (_isStreaming) return;
    await _streamSubscription?.cancel();
    _isStreaming = true;
    _activityLabel = 'Debugging file context';
    _isLoading = true;
    notifyListeners();
    final aiMessage = Message.aiStreaming(
      type: 'file_debug',
      language: _selectedLanguage,
    );
    _messages.add(aiMessage);
    _isLoading = false;
    notifyListeners();
    String fullResponse = '';
    try {
      final stream = _streamService.streamFileDebug(
        userId: _userId!,
        fileId: fileId,
        chatId: _currentChatId,
        error: error,
        difficulty: _selectedDifficulty,
      );
      _streamSubscription = stream.listen((chunk) async {
        if (chunk.error != null) {
          _errorMessage = chunk.error;
          _isStreaming = false;
          _activityLabel = 'Ready';
          notifyListeners();
          return;
        }
        if (chunk.done) {
          if (chunk.chatId != null) _currentChatId = chunk.chatId;
          if (_messages.isNotEmpty && _messages.last.role == 'ai') {
            _messages[_messages.length - 1] = _messages.last.copyWith(
              content: fullResponse,
              messageId: chunk.messageId,
            );
          }
          _isStreaming = false;
          _activityLabel = 'Ready';
          await _updateLatestCode();
          notifyListeners();
          loadChats();
          return;
        }
        fullResponse += chunk.text;
        if (_messages.isNotEmpty && _messages.last.role == 'ai') {
          _messages[_messages.length - 1] = _messages.last.copyWith(
            content: fullResponse,
          );
        }
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = 'File debug failed: $e';
      _isStreaming = false;
      _activityLabel = 'Ready';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _bootTimer?.cancel(); // CONCURRENCY FIX: Cleanup on provider destruction
    _heartbeatTimer?.cancel();
    _wsSubscription?.cancel();
    _streamSubscription?.cancel();
    _wsService.dispose();
    _streamService.dispose();
    super.dispose();
  }

  Future<void> _updateLatestCode() async {
    if (_messages.isEmpty) return;

    final lastMessage = _messages.last;
    final content = lastMessage.content;

    // Only proceed if the message actually contains a code block
    if (!content.contains('```')) {
      return;
    }

    final String msgId = lastMessage.messageId;

    if (_codeCache.containsKey(msgId)) {
      final cachedBlocks = _codeCache[msgId]!;
      if (cachedBlocks.isNotEmpty) {
        _latestLanguage = cachedBlocks.last['language'] ?? 'python';
        _latestCode = cachedBlocks.last['code'] ?? '';
      }
      return;
    }

    // MEMORY FIX: Keep cache size reasonable
    if (_codeCache.length > 20) {
      _codeCache.remove(_codeCache.keys.first);
    }

    final List<Map<String, String>> blocks = await compute(
      _parseCodeBlocks,
      content,
    );
    _codeCache[msgId] = blocks;

    if (blocks.isNotEmpty) {
      _latestLanguage = blocks.last['language'] ?? 'python';
      _latestCode = blocks.last['code'] ?? '';
    }

    notifyListeners();
  }
}
