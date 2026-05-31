import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/orchestration_provider.dart';

/// Code Genie 2.0 — Cinematic Orchestration Cockpit
///
/// A JARVIS-style engineering dashboard showing live orchestration
/// telemetry, agent activity, security SOC, and audit trails.
class OrchestrationDashboard extends StatefulWidget {
  const OrchestrationDashboard({super.key});

  @override
  State<OrchestrationDashboard> createState() => _OrchestrationDashboardState();
}

class _OrchestrationDashboardState extends State<OrchestrationDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrchestrationProvider>().startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 900;

    return Consumer<OrchestrationProvider>(
      builder: (context, orch, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF060810),
          body: CustomScrollView(
            slivers: [
              // ── Cinematic App Bar ──
              SliverAppBar(
                expandedHeight: 90,
                pinned: true,
                backgroundColor: const Color(0xFF060810),
                flexibleSpace: FlexibleSpaceBar(
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ORCHESTRATION COCKPIT',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: isSmallScreen ? 11 : 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!isSmallScreen)
                    Center(
                      child: Text(
                        'SYNCED: ${orch.lastRefreshedFormatted}  |  POLL: ${orch.refreshIntervalSeconds}s',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.timer, color: Color(0xFF06B6D4)),
                    tooltip: 'Adjust Refresh Interval',
                    onSelected: (seconds) => orch.setRefreshInterval(seconds),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 2,
                        child: Text(
                          '2s (Real-time)',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      PopupMenuItem(
                        value: 5,
                        child: Text(
                          '5s (Normal)',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      PopupMenuItem(
                        value: 10,
                        child: Text(
                          '10s (Relaxed)',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      PopupMenuItem(
                        value: 30,
                        child: Text(
                          '30s (Slow)',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
                    onPressed: () => orch.refresh(),
                  ),
                ],
              ),

              // ── Main Dashboard Grid ──
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Row 1: Top Stats
                    _buildStatRow(orch, isSmallScreen),
                    const SizedBox(height: 16),

                    // Row 2: Security SOC + Agent Activity
                    _buildSecurityAndAgents(orch, isSmallScreen),
                    const SizedBox(height: 16),

                    // Row 3: Audit Trail
                    _buildAuditTrail(orch),
                    const SizedBox(height: 16),

                    // Row 4: Pending Approvals
                    if (orch.approvals.isNotEmpty) _buildApprovalGates(orch),
                    const SizedBox(height: 16),

                    // Row 5: Active Workflows
                    _buildWorkflows(orch),
                    const SizedBox(height: 16),

                    // Row 6: Active Models & Rate Limits
                    _buildModelLimits(orch, isSmallScreen),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // TOP STATS ROW
  // ============================================================
  Widget _buildStatRow(OrchestrationProvider orch, bool isSmallScreen) {
    final cards = [
      _glowStat(
        'ORCHESTRATIONS',
        '${orch.totalOrchestrations}',
        Icons.hub,
        const Color(0xFF6366F1),
      ),
      _glowStat(
        'AGENT CALLS',
        '${orch.totalAgentCalls}',
        Icons.smart_toy,
        const Color(0xFF06B6D4),
      ),
      _glowStat(
        'SYNTHESES',
        '${orch.synthesisCount}',
        Icons.merge_type,
        const Color(0xFFF59E0B),
      ),
      _glowStat(
        'BLOCKED',
        '${orch.blocked}',
        Icons.shield,
        const Color(0xFFEF4444),
      ),
    ];

    if (isSmallScreen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
    }

    return Row(
      children: cards.map((e) => Expanded(child: e)).toList(),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  Widget _glowStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY SOC + AGENT ROLES
  // ============================================================
  Widget _buildSecurityAndAgents(
    OrchestrationProvider orch,
    bool isSmallScreen,
  ) {
    final securityCard = _glassCard(
      title: '🛡️ SECURITY OPERATIONS CENTER',
      titleColor: const Color(0xFF22C55E),
      child: Column(
        children: [
          _socRow(
            'Total Scanned',
            '${orch.totalScanned}',
            const Color(0xFF6366F1),
          ),
          _socRow('Clean', '${orch.clean}', const Color(0xFF22C55E)),
          _socRow('Flagged', '${orch.flagged}', const Color(0xFFF59E0B)),
          _socRow('Blocked', '${orch.blocked}', const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          // Threat level bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: orch.totalScanned > 0
                  ? (orch.clean / orch.totalScanned).clamp(0.0, 1.0)
                  : 1.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            orch.totalScanned > 0
                ? '${((orch.clean / orch.totalScanned) * 100).toStringAsFixed(1)}% CLEAN'
                : 'NO DATA',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF22C55E),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    final agentsCard = _glassCard(
      title: '🧬 EXPERT CIVILIZATION',
      titleColor: const Color(0xFF06B6D4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _agentChip('🗺️', 'Planner', const Color(0xFF6366F1)),
          _agentChip('🏗️', 'Architect', const Color(0xFF8B5CF6)),
          _agentChip('💻', 'Coder', const Color(0xFF06B6D4)),
          _agentChip('🔒', 'Auditor', const Color(0xFFEF4444)),
          _agentChip('📋', 'Compliance', const Color(0xFFF59E0B)),
          _agentChip('🕵️', 'Threat Intel', const Color(0xFFEC4899)),
          _agentChip('🐛', 'Debugger', const Color(0xFFF97316)),
          _agentChip('⚡', 'Optimizer', const Color(0xFF22D3EE)),
          _agentChip('🚀', 'DevOps', const Color(0xFF14B8A6)),
          _agentChip('👀', 'Reviewer', const Color(0xFFA78BFA)),
          _agentChip('🧬', 'Synthesizer', const Color(0xFFE2E8F0)),
        ],
      ),
    );

    if (isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [securityCard, const SizedBox(height: 16), agentsCard],
      ).animate().fadeIn(duration: 800.ms, delay: 200.ms);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: securityCard),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: agentsCard),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms);
  }

  Widget _socRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _agentChip(String emoji, String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AUDIT TRAIL
  // ============================================================
  Widget _buildAuditTrail(OrchestrationProvider orch) {
    final events = (orch.auditData['recent_events'] as List<dynamic>?) ?? [];

    return _glassCard(
      title: '📝 AUDIT TRAIL',
      titleColor: const Color(0xFFF59E0B),
      child: events.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No audit events yet',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : Column(
              children: events.reversed.take(8).map<Widget>((e) {
                final type = e['event_type'] ?? '';
                final agent = e['agent_name'] ?? '';
                final action = e['action'] ?? '';
                final color = _eventColor(type);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$agent → $action',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        (e['hash'] ?? '').toString().substring(0, 8),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms);
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'THINK':
        return const Color(0xFF6366F1);
      case 'PLAN':
        return const Color(0xFF06B6D4);
      case 'ACT':
        return const Color(0xFF22C55E);
      case 'OBSERVE':
        return const Color(0xFF8B5CF6);
      case 'COMPLETE':
        return const Color(0xFF14B8A6);
      case 'ERROR':
        return const Color(0xFFEF4444);
      case 'SECURITY':
        return const Color(0xFFF59E0B);
      case 'QUARANTINE':
        return const Color(0xFFEC4899);
      case 'SYNTHESIS':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ============================================================
  // APPROVAL GATES
  // ============================================================
  Widget _buildApprovalGates(OrchestrationProvider orch) {
    return _glassCard(
      title: '🔒 PENDING APPROVALS',
      titleColor: const Color(0xFFEF4444),
      child: Column(
        children: orch.approvals.map<Widget>((a) {
          final action = a['action'] ?? '';
          final agent = a['agent'] ?? '';
          final risk = a['risk_level'] ?? 'medium';
          final riskColor = risk == 'critical'
              ? const Color(0xFFEF4444)
              : risk == 'high'
              ? const Color(0xFFF59E0B)
              : const Color(0xFF06B6D4);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: riskColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$agent → $action',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Risk: ${risk.toUpperCase()}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF22C55E),
                    size: 28,
                  ),
                  onPressed: () => orch.resolveApproval(a['request_id'], true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                  onPressed: () => orch.resolveApproval(a['request_id'], false),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 600.ms).shakeX(hz: 2, amount: 2);
  }

  // ============================================================
  // ACTIVE WORKFLOWS
  // ============================================================
  Widget _buildWorkflows(OrchestrationProvider orch) {
    final wfStats = orch.stats['workflows'] as Map<String, dynamic>? ?? {};
    final active = wfStats['active_workflows'] as List<dynamic>? ?? [];

    return _glassCard(
      title: '⚙️ WORKFLOW ENGINE',
      titleColor: const Color(0xFF8B5CF6),
      child: active.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No active workflows — system idle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Created: ${wfStats['total_created'] ?? 0} | '
                    'Done: ${wfStats['completed'] ?? 0} | '
                    'Failed: ${wfStats['failed'] ?? 0}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: active.map<Widget>((w) {
                final state = w['state'] ?? '';
                return ListTile(
                  dense: true,
                  leading: _stateIcon(state),
                  title: Text(
                    w['goal'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    state.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                );
              }).toList(),
            ),
    ).animate().fadeIn(duration: 800.ms, delay: 600.ms);
  }

  Widget _stateIcon(String state) {
    switch (state) {
      case 'executing':
        return const Icon(
          Icons.play_circle,
          color: Color(0xFF22C55E),
          size: 20,
        );
      case 'waiting_approval':
        return const Icon(
          Icons.pause_circle,
          color: Color(0xFFF59E0B),
          size: 20,
        );
      case 'failed':
        return const Icon(Icons.error, color: Color(0xFFEF4444), size: 20);
      case 'completed':
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF06B6D4),
          size: 20,
        );
      default:
        return const Icon(
          Icons.hourglass_empty,
          color: Color(0xFF64748B),
          size: 20,
        );
    }
  }

  // ============================================================
  // GLASS CARD
  // ============================================================
  Widget _glassCard({
    required String title,
    required Color titleColor,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1219).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: titleColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MODEL RATE LIMITS CARD
  // ============================================================
  Widget _buildModelLimits(OrchestrationProvider orch, bool isSmallScreen) {
    final List<dynamic> rawModels = orch.modelLimits.isNotEmpty
        ? orch.modelLimits
        : [
            {
              'name': 'Google Gemini 2.0 Flash',
              'limit': '15 RPM | 1M TPM',
              'status': 'Optimal',
              'color': '0xFF22C55E',
              'tier': 'Default pool / custom key rotation fallback',
            },
            {
              'name': 'Llama 3.3 70B (Groq)',
              'limit': '30 RPM | 14,400 RPD',
              'status': 'Optimal',
              'color': '0xFF22C55E',
              'tier': 'High-speed local key failover fallback',
            },
            {
              'name': 'Qwen 2.5 Coder 32B (OpenRouter)',
              'limit': '20 RPM | Free Pool',
              'status': 'Optimal',
              'color': '0xFF22C55E',
              'tier': 'Alternative general backup tier',
            },
            {
              'name': 'Mistral Large (Mistral)',
              'limit': '5 RPM | Trial Tier',
              'status': 'Optimal',
              'color': '0xFF22C55E',
              'tier': 'Cognitive reasoning specialist',
            },
            {
              'name': 'GitHub Copilot Models',
              'limit': 'Unlimited (API key)',
              'status': 'Optimal',
              'color': '0xFF22C55E',
              'tier': 'Custom user credential fallback tier',
            },
          ];

    return _glassCard(
      title: '🤖 ACTIVE MODEL ORCHESTRATION & API RATE LIMITS',
      titleColor: const Color(0xFF06B6D4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Code Genie dynamically routes expert prompt sub-tasks across available model keys with automatic failovers when rate limits (429 errors) occur.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rawModels.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0xFF1E293B), height: 16),
            itemBuilder: (context, index) {
              final m = rawModels[index] as Map<String, dynamic>;
              final String colorHex = m['color'] as String? ?? '0xFF22C55E';
              final int colorVal = int.tryParse(colorHex) ?? 0xFF22C55E;
              final Color statusColor = Color(colorVal);

              return isSmallScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m['name'] as String,
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            _statusBadge(m['status'] as String, statusColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Limit: ${m['limit']}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6366F1),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m['tier'] as String,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['name'] as String,
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m['tier'] as String,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            m['limit'] as String,
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _statusBadge(m['status'] as String, statusColor),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
