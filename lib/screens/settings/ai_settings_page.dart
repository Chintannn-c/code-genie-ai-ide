import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/api_config.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';
import '../../widgets/settings/settings_slider.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Infra & Benchmark, 1: Autonomous Sandbox, 2: Cognitive RAG & Memory, 3: Calibration, 4: Console Telemetry
  Timer? _telemetryTimer;
  final math.Random _random = math.Random();
  bool _isBackendSyncLoading = true;

  // ── INFRASTRUCTURE STATES ──
  bool _geminiOutage = false;
  Map<String, Map<String, dynamic>> _models = {
    'Gemini 1.5 Pro': {'latency': 45, 'throughput': 2850, 'status': 'Generating', 'region': 'us-central1', 'load': 'Low', 'uptime': '99.98%', 'priority': 1, 'color': Color(0xFF3B82F6)},
    'Groq Llama 3': {'latency': 12, 'throughput': 6410, 'status': 'Streaming', 'region': 'us-east4', 'load': 'Medium', 'uptime': '99.95%', 'priority': 2, 'color': Color(0xFFF59E0B)},
    'OpenRouter Route': {'latency': 120, 'throughput': 1420, 'status': 'Idle', 'region': 'eu-west1', 'load': 'Low', 'uptime': '99.91%', 'priority': 3, 'color': Color(0xFF8B5CF6)},
    'Mistral Large': {'latency': 85, 'throughput': 1980, 'status': 'Reasoning', 'region': 'eu-central3', 'load': 'High', 'uptime': '99.94%', 'priority': 4, 'color': Color(0xFFEF4444)},
    'Claude 3.5 Sonnet': {'latency': 92, 'throughput': 2100, 'status': 'Idle', 'region': 'us-east1', 'load': 'Low', 'uptime': '99.99%', 'priority': 5, 'color': Color(0xFFEC4899)},
    'Local Llama 3.1': {'latency': 8, 'throughput': 3120, 'status': 'Offline', 'region': 'Local Server', 'load': 'Idle', 'uptime': '100.0%', 'priority': 6, 'color': Color(0xFF10B981)},
  };

  // ── STREAMING CONFIGS ──
  double _responseSpeed = 45.0; // char/sec
  double _chunkSize = 12.0; // tokens per emission
  bool _streamRecovery = true;
  bool _lowBandwidthMode = false;

  // ── AUTONOMOUS SANDBOX PERMISSIONS ──
  bool _permRead = true;
  bool _permWrite = false;
  bool _permExecute = false;
  bool _permInstall = false;
  bool _permDeploy = false;
  List<String> _sandboxLogs = [
    '[AUDIT] Sandbox initialized container sandbox-7a912',
    '[SECURE] Blocked attempt to delete .git/config directory',
    '[AUDIT] File modification request accepted for: lib/main.dart',
  ];

  // ── MULTI-AGENT DEBATE ARENA ──
  double _consensusScore = 84.0;
  List<Map<String, String>> _debateLogs = [
    {'agent': 'Security Auditor', 'msg': 'Recommends strict token signature validation inside auth handlers.'},
    {'agent': 'Scale Planner', 'msg': 'Suggests utilizing optimistic server state cache tables to offload database locks.'},
    {'agent': 'Code Optimizer', 'msg': 'Agrees with scale planner; AST verification verifies type integrity.'},
  ];

  // ── COGNITIVE RAG & MEMORY VAULT ──
  bool _staleEmbeddingIndex = false;
  final TextEditingController _memoryInputController = TextEditingController();
  List<Map<String, dynamic>> _memories = [
    {'id': 1, 'text': 'Architecture: Monorepo with FastAPI and Flutter Web release pipelines', 'pinned': true, 'encrypted': true, 'tier': 'Cloud Sync'},
    {'id': 2, 'text': 'Preference: Use custom glassmorphism BackdropFilter with Outfit fonts', 'pinned': true, 'encrypted': false, 'tier': 'Shared'},
    {'id': 3, 'text': 'Debug history: Resolving 502/Gateway timeout anomalies on Railway platform', 'pinned': false, 'encrypted': false, 'tier': 'Local Only'},
    {'id': 4, 'text': 'CodeStyle: Keep lines short and avoid Tailwind unless requested', 'pinned': false, 'encrypted': true, 'tier': 'Temporary'},
  ];

  // ── LIVE TELEMETRY CONSOLE logs ──
  List<String> _consoleLogs = [
    '🛰️ [WS] Connected to Central Intelligence Orchestrator (WebSocket secure)',
    '⚙️ [RAG] Vector database synchronized: 4,812 embedding chunks compiled',
    '🤖 [ORCHESTRATOR] Routing request to Gemini 1.5 Pro (Accuracy prioritize)',
  ];
  final ScrollController _consoleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startSimulatedTelemetry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBackendAiSettings();
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _memoryInputController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  void _startSimulatedTelemetry() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;

      setState(() {
        // Randomly adjust latencies & throughputs to simulate active network traffic
        _models.forEach((key, value) {
          if (key == 'Gemini 1.5 Pro' && _geminiOutage) {
            value['latency'] = 9999;
            value['throughput'] = 0;
            value['status'] = 'Offline';
            value['load'] = 'None';
          } else {
            final int baseLatency = key.contains('Groq') ? 12 : (key.contains('Local') ? 8 : (key.contains('OpenRouter') ? 120 : 70));
            value['latency'] = baseLatency + _random.nextInt(15) - 7;
            value['throughput'] = (value['throughput'] as int) + _random.nextInt(200) - 100;
            
            // Randomly rotate status
            if (_random.nextDouble() > 0.8) {
              final statuses = ['Idle', 'Streaming', 'Generating', 'Reasoning'];
              value['status'] = statuses[_random.nextInt(statuses.length)];
            }
          }
        });

        // Add a console telemetry log row dynamically
        final debugLogs = [
          '⚡ [INFERENCE] Streaming tokens: rate limit at ${_random.nextInt(10) + 90}% margin',
          '💾 [MEM] Hydrated long-term developer context preference vault keys',
          '🛡️ [SANDBOX] Audited command: "flutter pub get" successfully isolated',
          '🔗 [RAG] Context injector loaded: 3 relevant project files retrieved',
          '💡 [DEBATE] Convergence reached on scale benchmark logs',
        ];
        _consoleLogs.add(debugLogs[_random.nextInt(debugLogs.length)]);
        if (_consoleLogs.length > 50) _consoleLogs.removeAt(0);

        // Auto Scroll Console if active
        if (_selectedTab == 4 && _consoleScrollController.hasClients) {
          _consoleScrollController.animateTo(
            _consoleScrollController.position.maxScrollExtent + 24,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _fetchBackendAiSettings() async {
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;
    if (token == null) {
      setState(() => _isBackendSyncLoading = false);
      return;
    }

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/ai-settings');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['ai_settings'] != null) {
          final settings = data['ai_settings'];
          final sp = context.read<SettingsProvider>();
          
          await sp.updateAiSettings(
            temperature: (settings['temperature'] as num?)?.toDouble(),
            maxTokens: (settings['max_tokens'] as num?)?.toDouble(),
            creativity: (settings['creativity'] as num?)?.toDouble(),
            streaming: settings['streaming'] as bool?,
            autonomousMode: settings['autonomous_mode'] as bool?,
            debateMode: settings['debate_mode'] as bool?,
            ragContext: settings['rag_context'] as bool?,
            memoryPersist: settings['memory_persist'] as bool?,
          );
          
          setState(() {
            if (settings['memories'] != null) {
              _memories = List<Map<String, dynamic>>.from(
                (settings['memories'] as List).map((x) => Map<String, dynamic>.from(x)),
              );
            }
            _consoleLogs.add('✅ [WS-SYNC] Hydrated AI orchestration parameters from central MongoDB.');
          });
        }
      }
    } catch (e) {
      setState(() {
        _consoleLogs.add('⚠️ [SYNC-WARN] Failed to hydrate latest parameters from cloud server. Active local storage fallbacks.');
      });
      print('❌ [AiSettingsPage] Load Sync Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isBackendSyncLoading = false);
      }
    }
  }

  bool _isSyncing = false;
  String _syncStatusText = "Saved & Applied";

  Future<void> _syncAiSetting(String key, dynamic value) async {
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;
    if (token == null) return;

    setState(() {
      _isSyncing = true;
      _syncStatusText = "Syncing...";
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/ai-settings/update');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({key: value}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isSyncing = false;
          _syncStatusText = "Saved & Applied";
          _consoleLogs.add('✅ [WS-SYNC] Successfully pushed "$key: $value" to central PostgreSQL store.');
        });
      } else {
        throw Exception('Sync status ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatusText = "Offline Cache";
        _consoleLogs.add('⚠️ [SYNC-ERR] Failed to publish "$key" update. Saved in offline local store.');
      });
      print('❌ [AiSettingsPage] Sync Error: $e');
    }
  }

  void _triggerOutageSimulation() {
    setState(() {
      _geminiOutage = !_geminiOutage;
      if (_geminiOutage) {
        _consoleLogs.add('🚨 [AUTO-FAILOVER] Gemini 1.5 Pro failed (Timeout simulated). Auto-rerouting inference traffic to Groq Llama 3.');
        _models['Gemini 1.5 Pro']!['status'] = 'Offline';
        _models['Groq Llama 3']!['status'] = 'Fallback Active';
        _showToast('Gemini Outage simulated! Rerouted to Groq Llama 3.', isError: true);
      } else {
        _consoleLogs.add('✅ [AUTO-FAILOVER] Gemini 1.5 Pro restored. Normal routing priorities re-established.');
        _models['Gemini 1.5 Pro']!['status'] = 'Idle';
        _models['Groq Llama 3']!['status'] = 'Streaming';
        _showToast('Gemini recovery confirmed successfully!');
      }
    });
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : const Color(0xFF10B981),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141418).withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildTabSelector(isDark),
            Expanded(
              child: _isBackendSyncLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6))),
                          const SizedBox(height: 16),
                          Text(
                            'Synchronizing Cognitive Architectures...',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        ],
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                      child: _renderActiveTabContent(isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orchestration Center',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Central Intelligence Systems Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // Dynamic Sync Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isSyncing
                  ? Colors.blueAccent.withValues(alpha: 0.1)
                  : (_syncStatusText == "Offline Cache"
                      ? Colors.amber.withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isSyncing
                    ? Colors.blueAccent.withValues(alpha: 0.25)
                    : (_syncStatusText == "Offline Cache"
                        ? Colors.amber.withValues(alpha: 0.25)
                        : const Color(0xFF10B981).withValues(alpha: 0.25)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _isSyncing
                        ? Colors.blueAccent
                        : (_syncStatusText == "Offline Cache"
                            ? Colors.amber
                            : const Color(0xFF10B981)),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 800.ms),
                const SizedBox(width: 6),
                Text(
                  _syncStatusText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _isSyncing
                        ? Colors.blueAccent
                        : (_syncStatusText == "Offline Cache"
                            ? Colors.amber
                            : const Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // WebSocket connection telemetry
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 800.ms),
                const SizedBox(width: 6),
                Text(
                  'WS Active',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    final tabs = [
      {'icon': Icons.dns_rounded, 'label': 'Models'},
      {'icon': Icons.shield_rounded, 'label': 'Sandbox'},
      {'icon': Icons.psychology_rounded, 'label': 'RAG & Memory'},
      {'icon': Icons.tune_rounded, 'label': 'Calibration'},
      {'icon': Icons.terminal_rounded, 'label': 'Telemetry'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (ctx, idx) {
          final isSelected = _selectedTab == idx;
          final color = isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white30 : Colors.black38);
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = idx),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                ),
              ),
              child: Row(
                children: [
                  Icon(tabs[idx]['icon'] as IconData, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    tabs[idx]['label'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? (isDark ? Colors.white : Colors.black) : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _renderActiveTabContent(bool isDark) {
    switch (_selectedTab) {
      case 0:
        return _buildModelsInfrastructureTab(isDark);
      case 1:
        return _buildAutonomousSandboxTab(isDark);
      case 2:
        return _buildCognitiveRagMemoryTab(isDark);
      case 3:
        return _buildFineTuningCalibrationTab(isDark);
      case 4:
        return _buildConsoleTelemetryTab(isDark);
      default:
        return Container();
    }
  }

  // ─── TAB 1: MODELS INFRASTRUCTURE & STATUS ───
  Widget _buildModelsInfrastructureTab(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HEALTHY MODEL REPLICAS',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
            ),
            GestureDetector(
              onTap: _triggerOutageSimulation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _geminiOutage ? Colors.redAccent.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _geminiOutage ? Colors.redAccent.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dangerous_rounded, size: 12, color: _geminiOutage ? Colors.redAccent : Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      _geminiOutage ? 'Fix Simulated Outage' : 'Simulate Gemini Outage',
                      style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: _geminiOutage ? Colors.redAccent : Colors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Grid View of live cards
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _models.length,
          itemBuilder: (ctx, idx) {
            final key = _models.keys.elementAt(idx);
            final val = _models[key]!;
            final isOffline = val['status'] == 'Offline';
            final isFallback = val['status'] == 'Fallback Active';
            final cardColor = val['color'] as Color;

            return GlassCard(
              padding: const EdgeInsets.all(12),
              glowColor: isOffline ? Colors.redAccent : cardColor,
              glowIntensity: (isOffline || val['status'] == 'Idle') ? 0.03 : 0.14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          key,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOffline ? Colors.redAccent : (isFallback ? Colors.amber : const Color(0xFF10B981)),
                        ),
                      ).animate(onPlay: (c) => !isOffline ? c.repeat(reverse: true) : c.stop()).fadeOut(duration: 600.ms),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 10, color: Colors.white30),
                      const SizedBox(width: 4),
                      Text(
                        isOffline ? '0 t/s' : '${val['throughput']} t/s',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: isOffline ? Colors.white24 : Colors.white70),
                      ),
                      const Spacer(),
                      Text(
                        '${val['latency']}ms',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: isOffline ? Colors.white24 : cardColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Uptime: ${val['uptime']}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 8, color: isDark ? Colors.white24 : Colors.black26),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOffline
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : (isFallback ? Colors.amber.withValues(alpha: 0.15) : cardColor.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          val['status'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8, fontWeight: FontWeight.bold,
                            color: isOffline ? Colors.redAccent : (isFallback ? Colors.amber : cardColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'INTELLIGENCE PERFORMANCE BENCHMARK',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _buildBenchmarkRow('Gemini 1.5 Pro', 'Accuracy', '98/100', '0.0015', const Color(0xFF3B82F6), 0.98),
              _divider(isDark),
              _buildBenchmarkRow('Claude 3.5 Sonnet', 'Quality', '99/100', '0.0030', const Color(0xFFEC4899), 0.99),
              _divider(isDark),
              _buildBenchmarkRow('Groq Llama 3', 'Speed', '85/100', '0.0003', const Color(0xFFF59E0B), 0.85),
              _divider(isDark),
              _buildBenchmarkRow('Mistral Large', 'Reasoning', '91/100', '0.0025', const Color(0xFFEF4444), 0.91),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenchmarkRow(String name, String strength, String quality, String cost, Color color, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(strength, style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Q: $quality • \$$cost/1K tokens',
                style: GoogleFonts.jetBrainsMono(fontSize: 9, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: AUTONOMOUS SANDBOX & MULTI-AGENT DEBATE ───
  Widget _buildAutonomousSandboxTab(bool isDark) {
    final sp = context.watch<SettingsProvider>();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'AUTONOMOUS AGENT ORCHESTRATION',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsToggle(
          label: 'Autonomous Mode',
          subtitle: 'Allow specialized AI agents to plan and execute workflows',
          icon: Icons.rocket_launch_rounded,
          value: sp.autonomousMode,
          onChanged: (v) {
            sp.updateAiSettings(autonomousMode: v);
            setState(() {
              _consoleLogs.add('🛡️ [AUTONOMOUS] Mode changed to: $v');
            });
            _syncAiSetting('autonomous_mode', v);
          },
          accentColor: const Color(0xFFEC4899),
        ),
        const SizedBox(height: 12),
        if (sp.autonomousMode) ...[
          Text(
            'ISOLATION SANDBOX PERMISSIONS',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _buildSandboxSwitch('Read Repository Files', 'Can analyze workspace contents', _permRead, (v) => setState(() => _permRead = v)),
                _divider(isDark),
                _buildSandboxSwitch('Modify File System', 'Can refactor, write, and create files', _permWrite, (v) => setState(() => _permWrite = v)),
                _divider(isDark),
                _buildSandboxSwitch('Execute Commands', 'Can run compiling tests and linters', _permExecute, (v) => setState(() => _permExecute = v)),
                _divider(isDark),
                _buildSandboxSwitch('Install System Dependencies', 'Can run commands like npm install or pip install', _permInstall, (v) => setState(() => _permInstall = v)),
                _divider(isDark),
                _buildSandboxSwitch('Production Build Deployment', 'Can deploy compiled web builds', _permDeploy, (v) => setState(() => _permDeploy = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SANDBOX AUDIT LOGS',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _sandboxLogs.map((log) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    log,
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: log.contains('Blocked') ? Colors.redAccent : Colors.white54),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'MULTI-AGENT DEBATE ARENA',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsToggle(
          label: 'AI Debate Mode',
          subtitle: 'Launch concurrent specialized agents to debate code answers',
          icon: Icons.forum_rounded,
          value: sp.debateMode,
          onChanged: (v) {
            sp.updateAiSettings(debateMode: v);
            setState(() {
              _consoleLogs.add('💬 [DEBATE] Debate mode changed to: $v');
            });
            _syncAiSetting('debate_mode', v);
          },
          accentColor: const Color(0xFFD855F7),
        ),
        const SizedBox(height: 12),
        if (sp.debateMode) ...[
          GlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Consensus Threshold', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${_consensusScore.toInt()}%', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFD855F7))),
                  ],
                ),
                Slider(
                  value: _consensusScore,
                  min: 50, max: 100,
                  divisions: 10,
                  activeColor: const Color(0xFFD855F7),
                  onChanged: (v) => setState(() => _consensusScore = v),
                ),
                _divider(isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.diversity_3_rounded, size: 16, color: Color(0xFFD855F7)),
                    const SizedBox(width: 10),
                    Text('Specialized Debating Members', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _debateAgentBadge('Performance Specialist'),
                    _debateAgentBadge('Security Auditor'),
                    _debateAgentBadge('Scale Planner'),
                    _debateAgentBadge('Quality Assurer'),
                  ],
                ),
                const SizedBox(height: 14),
                _divider(isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Text('Active Argument Arena Feed', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60)),
                  ],
                ),
                const SizedBox(height: 10),
                ..._debateLogs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('[${log['agent']}]: ', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD855F7))),
                        Expanded(child: Text(log['msg']!, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSandboxSwitch(String title, String subtitle, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white30)),
              ],
            ),
          ),
          Switch.adaptive(
            value: val,
            onChanged: onChanged,
            activeColor: const Color(0xFFEC4899),
          ),
        ],
      ),
    );
  }

  Widget _debateAgentBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD855F7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD855F7).withValues(alpha: 0.25)),
      ),
      child: Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD855F7))),
    );
  }

  // ─── TAB 3: COGNITIVE RAG & MEMORY VAULT ───
  Widget _buildCognitiveRagMemoryTab(bool isDark) {
    final sp = context.watch<SettingsProvider>();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'RETRIEVAL-AUGMENTED GENERATION (RAG)',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsToggle(
          label: 'RAG Context Injection',
          subtitle: 'Inject vector embeddings and codebase context dynamically',
          icon: Icons.dataset_linked_rounded,
          value: sp.ragContext,
          onChanged: (v) {
            sp.updateAiSettings(ragContext: v);
            setState(() {
              _consoleLogs.add('💾 [RAG] Context injection toggled to: $v');
            });
            _syncAiSetting('rag_context', v);
          },
          accentColor: const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        if (sp.ragContext) ...[
          GlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Vector Sync Interrupted', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    Switch.adaptive(
                      value: _staleEmbeddingIndex,
                      onChanged: (v) {
                        setState(() => _staleEmbeddingIndex = v);
                        if (_staleEmbeddingIndex) {
                          _showToast('Warning: Embedding Index Stale!', isError: true);
                        }
                      },
                      activeColor: Colors.redAccent,
                    ),
                  ],
                ),
                if (_staleEmbeddingIndex) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25))),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vector index synch delayed: Semantic retrieval fallbacks are currently serving offline workspace context.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _divider(isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Text('Currently Active RAG Sources', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60)),
                  ],
                ),
                const SizedBox(height: 10),
                _ragSourceTile('lib/screens/settings/account_page.dart', '1,835 lines • Compiled 2 min ago'),
                _ragSourceTile('backend/app/routes/auth.py', '413 lines • Synchronized now'),
                _ragSourceTile('Central MongoDB User Identity Collection', 'Database Index key match: 99.4%'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'LONG-TERM COGNITIVE MEMORY VAULT',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsToggle(
          label: 'Memory Persistence',
          subtitle: 'Persist developer preference contexts across multiple sessions',
          icon: Icons.memory_rounded,
          value: sp.memoryPersist,
          onChanged: (v) {
            sp.updateAiSettings(memoryPersist: v);
            setState(() {
              _consoleLogs.add('🧠 [MEMORY] Memory persistence toggled to: $v');
            });
            _syncAiSetting('memory_persist', v);
          },
          accentColor: const Color(0xFF06B6D4),
        ),
        const SizedBox(height: 12),
        if (sp.memoryPersist) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cognitive Memory Inspector', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 10),
                // Text field to add memory
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _memoryInputController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Type coding preference memory here...',
                          hintStyle: TextStyle(color: Colors.white24),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF06B6D4)),
                      onPressed: () {
                        if (_memoryInputController.text.trim().isEmpty) return;
                        setState(() {
                          _memories.add({
                            'id': DateTime.now().millisecondsSinceEpoch,
                            'text': _memoryInputController.text,
                            'pinned': false,
                            'encrypted': false,
                            'tier': 'Cloud Sync',
                          });
                          _memoryInputController.clear();
                        });
                        _syncAiSetting('memories', _memories);
                        _showToast('Developer preference recorded successfully!');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _divider(isDark),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _memories.length,
                  itemBuilder: (ctx, idx) {
                    final item = _memories[idx];
                    final isPinned = item['pinned'] == true;
                    final isEncrypted = item['encrypted'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isEncrypted ? Icons.enhanced_encryption_rounded : Icons.bubble_chart_rounded,
                            size: 14,
                            color: isEncrypted ? Colors.amber : const Color(0xFF06B6D4),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEncrypted ? '••••••••••••••••••••••••••••••••••••••••' : item['text'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontStyle: isEncrypted ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        item['tier'] ?? 'Cloud Sync',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.white30, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => item['pinned'] = !isPinned);
                                        _syncAiSetting('memories', _memories);
                                      },
                                      child: Icon(
                                        isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                        size: 12,
                                        color: isPinned ? Colors.tealAccent : Colors.white30,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => item['encrypted'] = !isEncrypted);
                                        _syncAiSetting('memories', _memories);
                                        _showToast(isEncrypted ? 'Decryption key authorized.' : 'Memory encrypted via AES-256 cloud cipher.');
                                      },
                                      child: Icon(
                                        isEncrypted ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                        size: 12,
                                        color: isEncrypted ? Colors.tealAccent : Colors.white30,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _memories.removeAt(idx));
                                        _syncAiSetting('memories', _memories);
                                        _showToast('Memory item deleted.');
                                      },
                                      child: const Icon(Icons.delete_outline_rounded, size: 12, color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _ragSourceTile(String path, String size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, size: 12, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                Text(size, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.white24)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: CALIBRATION & ESTIMATION SLIDERS ───
  Widget _buildFineTuningCalibrationTab(bool isDark) {
    final sp = context.watch<SettingsProvider>();

    // Dynamic cost calculator based on tokens chosen
    final double costPerRequest = (sp.maxTokens * 0.0000015);
    final int predictedLatencySec = (sp.maxTokens / 1500).ceil();

    // Creative preview message
    String creativeRouteStyle = 'Deterministic Model prioritization. Deep AST Validation enabled.';
    if (sp.creativity > 0.3) creativeRouteStyle = 'Balanced models. Hybrid reasoning flow enabled.';
    if (sp.creativity > 0.7) creativeRouteStyle = 'Multi-agent creative models. Brainstorming pipelines.';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'STREAMING RESPONSE ENGINE CONFIGS',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsToggle(
          label: 'Streaming Responses',
          subtitle: 'Render output token-by-token progressively',
          icon: Icons.stream_rounded,
          value: sp.streaming,
          onChanged: (v) {
            sp.updateAiSettings(streaming: v);
            setState(() {
              _consoleLogs.add('⚡ [STREAMING] streaming responses switched: $v');
            });
            _syncAiSetting('streaming', v);
          },
          accentColor: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 8),
        if (sp.streaming) ...[
          GlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Response Delivery Speed', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${_responseSpeed.toInt()} char/s', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF3B82F6))),
                  ],
                ),
                Slider(
                  value: _responseSpeed,
                  min: 10, max: 100,
                  divisions: 9,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => setState(() => _responseSpeed = v),
                ),
                _divider(isDark),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Token Chunk Emission Size', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${_chunkSize.toInt()} tokens', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF3B82F6))),
                  ],
                ),
                Slider(
                  value: _chunkSize,
                  min: 2, max: 32,
                  divisions: 15,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => setState(() => _chunkSize = v),
                ),
                _divider(isDark),
                _buildSandboxSwitch('Low-Bandwidth Mobile Mode', 'Optimize network streaming layers', _lowBandwidthMode, (v) => setState(() => _lowBandwidthMode = v)),
                _divider(isDark),
                _buildSandboxSwitch('Auto-Stream Recovery layers', 'Retry dropped streaming sockets quietly', _streamRecovery, (v) => setState(() => _streamRecovery = v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'HYPERPARAMETER TUNING CALIBRATOR',
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SettingsSlider(
          label: 'Temperature',
          subtitle: 'Tune temperature parameters',
          icon: Icons.thermostat_rounded,
          value: sp.temperature,
          min: 0, max: 2,
          divisions: 20,
          onChanged: (v) {
            sp.updateAiSettings(temperature: v);
            _syncAiSetting('temperature', v);
          },
          accentColor: const Color(0xFFF59E0B),
        ),
        // Live Preview Panel for Temperature
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🌡️ Real-Time Temperature Inference Preview:', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Precision: ${sp.temperature < 0.5 ? 'Strictly Precise' : (sp.temperature > 1.3 ? 'Highly Experimental' : 'Standard Balanced')}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white54)),
                  Text('Hallucination Risk: ${sp.temperature < 0.5 ? '0%' : (sp.temperature > 1.3 ? '85%' : '20%')}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white54)),
                ],
              ),
            ],
          ),
        ),
        SettingsSlider(
          label: 'Max Output Tokens',
          subtitle: 'Configure maximum tokens limit',
          icon: Icons.token_rounded,
          value: sp.maxTokens,
          min: 256, max: 8192,
          divisions: 31,
          valueLabel: (v) => v.toInt().toString(),
          onChanged: (v) {
            sp.updateAiSettings(maxTokens: v);
            _syncAiSetting('max_tokens', v);
          },
          accentColor: const Color(0xFF3B82F6),
        ),
        // Token Estimation details
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💰 Live Response Budget Estimates:', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Inference Cost projection: \$${costPerRequest.toStringAsFixed(5)}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white54)),
                  Text('Latency expectation: < $predictedLatencySec sec', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white54)),
                ],
              ),
            ],
          ),
        ),
        SettingsSlider(
          label: 'Creativity vs Accuracy',
          subtitle: 'Balance cognitive focus settings',
          icon: Icons.balance_rounded,
          value: sp.creativity,
          min: 0, max: 1,
          divisions: 10,
          valueLabel: (v) => v <= 0.3 ? 'Precise' : (v >= 0.7 ? 'Creative' : 'Balanced'),
          onChanged: (v) {
            sp.updateAiSettings(creativity: v);
            _syncAiSetting('creativity', v);
          },
          accentColor: const Color(0xFFEC4899),
        ),
        // Live routing preview panel
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔗 Dynamic Routing Reasoning Strategy:', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFEC4899))),
              const SizedBox(height: 4),
              Text(
                creativeRouteStyle,
                style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB 5: TELEMETRY DEBUGGING CONSOLE ───
  Widget _buildConsoleTelemetryTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTERPRISE SECURITY POLICIES',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _buildSandboxSwitch('Prompt Injection Shielding', 'Block adversarial heuristic attacks', true, (v) {}),
                _divider(isDark),
                _buildSandboxSwitch('GPU Acceleration overrides', 'Enable system hardware parsing', true, (v) {}),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'REAL-TIME ORCHESTRATION CONSOLE TELEMETRY',
            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF040406),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView.builder(
                controller: _consoleScrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: _consoleLogs.length,
                itemBuilder: (ctx, idx) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _consoleLogs[idx],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: _consoleLogs[idx].contains('🚨') ? Colors.redAccent : (_consoleLogs[idx].contains('✅') ? Colors.greenAccent : Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12);
  }
}
