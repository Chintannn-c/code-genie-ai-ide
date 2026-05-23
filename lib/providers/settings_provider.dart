import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';

/// Global state provider for persistent system settings.
class SettingsProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  StreamSubscription? _wsSubscription;

  // Key prefixes for persistence
  static const String _prefixAi = 'ai_setting_';
  static const String _prefixKey = 'api_key_';
  static const String _prefixEditor = 'editor_setting_';
  static const String _prefixAppearance = 'appearance_setting_';

  // State caches
  // ── AI Settings ──
  double _temperature = 0.7;
  double _maxTokens = 4096.0;
  double _creativity = 0.6;
  bool _streaming = true;
  bool _autonomousMode = false;
  bool _debateMode = false;
  bool _ragContext = true;
  bool _memoryPersist = false;

  // ── API Key Vault (Encrypted/Hidden) ──
  String _geminiApiKey = '';
  String _groqApiKey = '';
  String _openrouterApiKey = '';
  String _githubApiKey = '';
  String _mistralApiKey = '';

  // ── Editor Settings ──
  int _selectedFont = 0;
  double _fontSize = 14.0;
  int _tabSize = 2;
  bool _autoSave = true;
  bool _wordWrap = true;
  bool _minimap = false;
  bool _vimMode = false;
  bool _aiSuggestions = true;
  bool _linting = true;
  bool _formatOnSave = true;

  // ── Appearance Settings ──
  int _selectedTheme = 0;
  int _selectedAccent = 0;
  double _blurIntensity = 0.7;
  double _animationSpeed = 0.5;
  bool _particles = true;
  bool _reduceMotion = false;

  // Getters ─ AI Settings
  double get temperature => _temperature;
  double get maxTokens => _maxTokens;
  double get creativity => _creativity;
  bool get streaming => _streaming;
  bool get autonomousMode => _autonomousMode;
  bool get debateMode => _debateMode;
  bool get ragContext => _ragContext;
  bool get memoryPersist => _memoryPersist;

  // Getters ─ API Keys
  String get geminiApiKey => _geminiApiKey;
  String get groqApiKey => _groqApiKey;
  String get openrouterApiKey => _openrouterApiKey;
  String get githubApiKey => _githubApiKey;
  String get mistralApiKey => _mistralApiKey;

  // Getters ─ Editor Settings
  int get selectedFont => _selectedFont;
  double get fontSize => _fontSize;
  int get tabSize => _tabSize;
  bool get autoSave => _autoSave;
  bool get wordWrap => _wordWrap;
  bool get minimap => _minimap;
  bool get vimMode => _vimMode;
  bool get aiSuggestions => _aiSuggestions;
  bool get linting => _linting;
  bool get formatOnSave => _formatOnSave;

  // Getters ─ Appearance Settings
  int get selectedTheme => _selectedTheme;
  int get selectedAccent => _selectedAccent;
  double get blurIntensity => _blurIntensity;
  double get animationSpeed => _animationSpeed;
  bool get particles => _particles;
  bool get reduceMotion => _reduceMotion;

  SettingsProvider() {
    _loadSettings();
    _subscribeToWebsocketEvents();
  }

  void _subscribeToWebsocketEvents() {
    _wsSubscription = WebSocketService().stream.listen((event) {
      if (event['type'] == 'settings_update') {
        final settings = event['ai_settings'];
        if (settings != null) {
          updateAiSettings(
            temperature: (settings['temperature'] as num?)?.toDouble(),
            maxTokens: (settings['max_tokens'] as num?)?.toDouble(),
            creativity: (settings['creativity'] as num?)?.toDouble(),
            streaming: settings['streaming'] as bool?,
            autonomousMode: settings['autonomous_mode'] as bool?,
            debateMode: settings['debate_mode'] as bool?,
            ragContext: settings['rag_context'] as bool?,
            memoryPersist: settings['memory_persist'] as bool?,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load AI settings
    _temperature = prefs.getDouble('${_prefixAi}temperature') ?? 0.7;
    _maxTokens = prefs.getDouble('${_prefixAi}max_tokens') ?? 4096.0;
    _creativity = prefs.getDouble('${_prefixAi}creativity') ?? 0.6;
    _streaming = prefs.getBool('${_prefixAi}streaming') ?? true;
    _autonomousMode = prefs.getBool('${_prefixAi}autonomous_mode') ?? false;
    _debateMode = prefs.getBool('${_prefixAi}debate_mode') ?? false;
    _ragContext = prefs.getBool('${_prefixAi}rag_context') ?? true;
    _memoryPersist = prefs.getBool('${_prefixAi}memory_persist') ?? false;

    // Load API keys from secure storage, with a SharedPreferences fallback for migration.
    _geminiApiKey = await _readApiKey('gemini', prefs);
    _groqApiKey = await _readApiKey('groq', prefs);
    _openrouterApiKey = await _readApiKey('openrouter', prefs);
    _githubApiKey = await _readApiKey('github', prefs);
    _mistralApiKey = await _readApiKey('mistral', prefs);

    // Load Editor settings
    _selectedFont = prefs.getInt('${_prefixEditor}selected_font') ?? 0;
    _fontSize = prefs.getDouble('${_prefixEditor}font_size') ?? 14.0;
    _tabSize = prefs.getInt('${_prefixEditor}tab_size') ?? 2;
    _autoSave = prefs.getBool('${_prefixEditor}auto_save') ?? true;
    _wordWrap = prefs.getBool('${_prefixEditor}word_wrap') ?? true;
    _minimap = prefs.getBool('${_prefixEditor}minimap') ?? false;
    _vimMode = prefs.getBool('${_prefixEditor}vim_mode') ?? false;
    _aiSuggestions = prefs.getBool('${_prefixEditor}ai_suggestions') ?? true;
    _linting = prefs.getBool('${_prefixEditor}linting') ?? true;
    _formatOnSave = prefs.getBool('${_prefixEditor}format_on_save') ?? true;

    // Load Appearance settings
    _selectedTheme = prefs.getInt('${_prefixAppearance}selected_theme') ?? 0;
    _selectedAccent = prefs.getInt('${_prefixAppearance}selected_accent') ?? 0;
    _blurIntensity =
        prefs.getDouble('${_prefixAppearance}blur_intensity') ?? 0.7;
    _animationSpeed =
        prefs.getDouble('${_prefixAppearance}animation_speed') ?? 0.5;
    _particles = prefs.getBool('${_prefixAppearance}particles') ?? true;
    _reduceMotion = prefs.getBool('${_prefixAppearance}reduce_motion') ?? false;

    notifyListeners();
  }

  // Setter ─ AI Settings
  Future<void> updateAiSettings({
    double? temperature,
    double? maxTokens,
    double? creativity,
    bool? streaming,
    bool? autonomousMode,
    bool? debateMode,
    bool? ragContext,
    bool? memoryPersist,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (temperature != null) {
      _temperature = temperature;
      await prefs.setDouble('${_prefixAi}temperature', temperature);
    }
    if (maxTokens != null) {
      _maxTokens = maxTokens;
      await prefs.setDouble('${_prefixAi}max_tokens', maxTokens);
    }
    if (creativity != null) {
      _creativity = creativity;
      await prefs.setDouble('${_prefixAi}creativity', creativity);
    }
    if (streaming != null) {
      _streaming = streaming;
      await prefs.setBool('${_prefixAi}streaming', streaming);
    }
    if (autonomousMode != null) {
      _autonomousMode = autonomousMode;
      await prefs.setBool('${_prefixAi}autonomous_mode', autonomousMode);
    }
    if (debateMode != null) {
      _debateMode = debateMode;
      await prefs.setBool('${_prefixAi}debate_mode', debateMode);
    }
    if (ragContext != null) {
      _ragContext = ragContext;
      await prefs.setBool('${_prefixAi}rag_context', ragContext);
    }
    if (memoryPersist != null) {
      _memoryPersist = memoryPersist;
      await prefs.setBool('${_prefixAi}memory_persist', memoryPersist);
    }
    notifyListeners();
  }

  // Setter ─ API Keys
  Future<void> updateApiKey(String provider, String value) async {
    switch (provider.toLowerCase()) {
      case 'gemini':
        _geminiApiKey = value;
        await _writeApiKey('gemini', value);
        break;
      case 'groq':
        _groqApiKey = value;
        await _writeApiKey('groq', value);
        break;
      case 'openrouter':
        _openrouterApiKey = value;
        await _writeApiKey('openrouter', value);
        break;
      case 'github':
        _githubApiKey = value;
        await _writeApiKey('github', value);
        break;
      case 'mistral':
        _mistralApiKey = value;
        await _writeApiKey('mistral', value);
        break;
    }
    notifyListeners();
  }

  // Setter ─ Editor Settings
  Future<String> _readApiKey(String provider, SharedPreferences prefs) async {
    final key = '${_prefixKey}$provider';
    final secureValue = await _secureStorage.read(key: key);
    return secureValue ?? prefs.getString(key) ?? '';
  }

  Future<void> _writeApiKey(String provider, String value) async {
    final key = '${_prefixKey}$provider';
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: cleanValue);
    }
  }

  Future<void> updateEditorSettings({
    int? selectedFont,
    double? fontSize,
    int? tabSize,
    bool? autoSave,
    bool? wordWrap,
    bool? minimap,
    bool? vimMode,
    bool? aiSuggestions,
    bool? linting,
    bool? formatOnSave,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedFont != null) {
      _selectedFont = selectedFont;
      await prefs.setInt('${_prefixEditor}selected_font', selectedFont);
    }
    if (fontSize != null) {
      _fontSize = fontSize;
      await prefs.setDouble('${_prefixEditor}font_size', fontSize);
    }
    if (tabSize != null) {
      _tabSize = tabSize;
      await prefs.setInt('${_prefixEditor}tab_size', tabSize);
    }
    if (autoSave != null) {
      _autoSave = autoSave;
      await prefs.setBool('${_prefixEditor}auto_save', autoSave);
    }
    if (wordWrap != null) {
      _wordWrap = wordWrap;
      await prefs.setBool('${_prefixEditor}word_wrap', wordWrap);
    }
    if (minimap != null) {
      _minimap = minimap;
      await prefs.setBool('${_prefixEditor}minimap', minimap);
    }
    if (vimMode != null) {
      _vimMode = vimMode;
      await prefs.setBool('${_prefixEditor}vim_mode', vimMode);
    }
    if (aiSuggestions != null) {
      _aiSuggestions = aiSuggestions;
      await prefs.setBool('${_prefixEditor}ai_suggestions', aiSuggestions);
    }
    if (linting != null) {
      _linting = linting;
      await prefs.setBool('${_prefixEditor}linting', linting);
    }
    if (formatOnSave != null) {
      _formatOnSave = formatOnSave;
      await prefs.setBool('${_prefixEditor}format_on_save', formatOnSave);
    }
    notifyListeners();
  }

  // Setter ─ Appearance Settings
  Future<void> updateAppearanceSettings({
    int? selectedTheme,
    int? selectedAccent,
    double? blurIntensity,
    double? animationSpeed,
    bool? particles,
    bool? reduceMotion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedTheme != null) {
      _selectedTheme = selectedTheme;
      await prefs.setInt('${_prefixAppearance}selected_theme', selectedTheme);
    }
    if (selectedAccent != null) {
      _selectedAccent = selectedAccent;
      await prefs.setInt('${_prefixAppearance}selected_accent', selectedAccent);
    }
    if (blurIntensity != null) {
      _blurIntensity = blurIntensity;
      await prefs.setDouble(
        '${_prefixAppearance}blur_intensity',
        blurIntensity,
      );
    }
    if (animationSpeed != null) {
      _animationSpeed = animationSpeed;
      await prefs.setDouble(
        '${_prefixAppearance}animation_speed',
        animationSpeed,
      );
    }
    if (particles != null) {
      _particles = particles;
      await prefs.setBool('${_prefixAppearance}particles', particles);
    }
    if (reduceMotion != null) {
      _reduceMotion = reduceMotion;
      await prefs.setBool('${_prefixAppearance}reduce_motion', reduceMotion);
    }
    notifyListeners();
  }
}
