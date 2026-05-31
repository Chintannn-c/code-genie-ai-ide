import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _expandedEventId;

  // Webhook text editing controllers
  late TextEditingController _slackController;
  late TextEditingController _discordController;
  late TextEditingController _teamsController;
  late TextEditingController _customWebhookController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    final np = context.read<NotificationProvider>();
    _slackController = TextEditingController(text: np.slackWebhookUrl);
    _discordController = TextEditingController(text: np.discordWebhookUrl);
    _teamsController = TextEditingController(text: np.teamsWebhookUrl);
    _customWebhookController = TextEditingController(text: np.customWebhookUrl);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slackController.dispose();
    _discordController.dispose();
    _teamsController.dispose();
    _customWebhookController.dispose();
    super.dispose();
  }

  // Soft haptic triggers
  void _triggerHaptic(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.success:
        HapticFeedback.vibrate();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060608) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, np, isDark),
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildLiveEventFeed(np, isDark),
                  _buildNotificationPreferences(np, isDark),
                  _buildAdvancedSettings(np, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotificationProvider np, bool isDark) {
    Color syncColor;
    IconData syncIcon;

    if (np.syncStatus == "Saved & Applied") {
      syncColor = const Color(0xFF10B981);
      syncIcon = Icons.check_circle_rounded;
    } else if (np.syncStatus == "Syncing...") {
      syncColor = const Color(0xFF3B82F6);
      syncIcon = Icons.sync_rounded;
    } else {
      syncColor = const Color(0xFFEF4444);
      syncIcon = Icons.error_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              _triggerHaptic(HapticFeedbackType.light);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operations Center',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Code Genie Distributed Event Orchestrator',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          // SYNC TELEMETRY BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: syncColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: syncColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (np.isSyncing)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  )
                else
                  Icon(syncIcon, size: 11, color: syncColor),
                const SizedBox(width: 6),
                Text(
                  np.syncStatus.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: syncColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121216) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: isDark ? Colors.white : Colors.black87,
        unselectedLabelColor: isDark ? Colors.white30 : Colors.black38,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: "Live Events"),
          Tab(text: "Channels"),
          Tab(text: "Advanced"),
        ],
      ),
    );
  }

  Widget _buildLiveEventFeed(NotificationProvider np, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [


        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REAL-TIME PIPELINE STREAM',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 1.2,
                  ),
                ),
                if (np.notifications.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _triggerHaptic(HapticFeedbackType.light);
                      np.clearAll();
                    },
                    child: Text(
                      'CLEAR ALL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (np.notifications.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(isDark),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final notif = np.notifications[index];
                final isExpanded = _expandedEventId == notif.id;
                return _buildAnimatedEventCard(notif, isExpanded, isDark, np);
              },
              childCount: np.notifications.length,
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedEventCard(
    NotificationModel notif,
    bool isExpanded,
    bool isDark,
    NotificationProvider np,
  ) {
    Color severityColor;
    IconData eventIcon;

    switch (notif.type) {
      case 'ai':
        severityColor = const Color(0xFF8B5CF6);
        eventIcon = Icons.smart_toy_rounded;
        break;
      case 'model_failure':
        severityColor = const Color(0xFFF59E0B);
        eventIcon = Icons.warning_amber_rounded;
        break;
      case 'deployment':
        severityColor = const Color(0xFF06B6D4);
        eventIcon = Icons.rocket_launch_rounded;
        break;
      case 'security':
        severityColor = const Color(0xFFEF4444);
        eventIcon = Icons.shield_rounded;
        break;
      default:
        severityColor = const Color(0xFF3B82F6);
        eventIcon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          child: GestureDetector(
            onTap: () {
              _triggerHaptic(HapticFeedbackType.light);
              setState(() {
                _expandedEventId = isExpanded ? null : notif.id;
              });
              if (!notif.isRead) {
                np.markAsRead(notif.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF101014).withValues(alpha: 0.7)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isExpanded
                      ? severityColor.withValues(alpha: 0.4)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                ),
                boxShadow: [
                  if (isExpanded)
                    BoxShadow(
                      color: severityColor.withValues(alpha: 0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(eventIcon, size: 18, color: severityColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.body,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat.jm().format(notif.timestamp),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!notif.isRead)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: severityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (isExpanded && notif.data != null) ...[
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      "LIVE DIAGNOSTIC RETRIEVAL",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: severityColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Renders rich trace elements dynamically
                    ...notif.data!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${entry.key.replaceAll('_', ' ').toUpperCase()}: ",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideX(begin: -0.1, duration: 250.ms, curve: Curves.easeOut);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_rounded,
              size: 64,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
          const SizedBox(height: 20),
          Text(
            'Ops Pipeline Clear',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Listening to live server event socket streams...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferences(NotificationProvider np, bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _buildSectionHeader("GLOBAL ROUTING CHANNELS", isDark),
        _buildSleekToggle(
          "Push Notifications",
          "Register device token & establish live websocket connection pipelines",
          np.push,
          (val) {
            _triggerHaptic(HapticFeedbackType.light);
            np.updateSettings(pushVal: val);
          },
          const Color(0xFF3B82F6),
          Icons.notifications_active_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "AI Workflow Alerts",
          "Track plan completion, autonomous loop progress, and agent code reviews",
          np.aiAlerts,
          (val) {
            _triggerHaptic(HapticFeedbackType.light);
            np.updateSettings(aiAlertsVal: val);
          },
          const Color(0xFF8B5CF6),
          Icons.smart_toy_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Security Intrusion Alerts",
          "Immediate geo-IP tracking warning on suspicious logings or threat signs",
          np.securityAlerts,
          (val) {
            _triggerHaptic(HapticFeedbackType.heavy);
            np.updateSettings(securityAlertsVal: val);
          },
          const Color(0xFFEF4444),
          Icons.shield_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Model Failover Reroutes",
          "Live updates when primary gateway drops out and switches to fallbacks",
          np.modelFailure,
          (val) {
            _triggerHaptic(HapticFeedbackType.medium);
            np.updateSettings(modelFailureVal: val);
          },
          const Color(0xFFF59E0B),
          Icons.swap_horiz_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Deployment & CI/CD Pipelines",
          "Monitor environment builds, Git triggers, and Railway diagnostic rollbacks",
          np.deployment,
          (val) {
            _triggerHaptic(HapticFeedbackType.light);
            np.updateSettings(deploymentVal: val);
          },
          const Color(0xFF06B6D4),
          Icons.cloud_done_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Team Collaboration",
          "Presence alerts, shared workspace logs, live programming code edits",
          np.collaboration,
          (val) {
            _triggerHaptic(HapticFeedbackType.light);
            np.updateSettings(collaborationVal: val);
          },
          const Color(0xFFEC4899),
          Icons.group_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Intelligent Email Digests",
          "Compile beautiful daily and weekly analytical summaries of productivity",
          np.email,
          (val) {
            _triggerHaptic(HapticFeedbackType.light);
            np.updateSettings(emailVal: val);
          },
          const Color(0xFF64748B),
          Icons.email_rounded,
          isDark,
        ),
        _buildSleekToggle(
          "Adaptive Sound & Haptics",
          "Play responsive acoustic tones and varying frequency vibrations",
          np.sound,
          (val) {
            _triggerHaptic(HapticFeedbackType.success);
            np.updateSettings(soundVal: val);
          },
          const Color(0xFFA855F7),
          Icons.volume_up_rounded,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSleekToggle(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white30 : Colors.black38,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          activeTrackColor: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(NotificationProvider np, bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _buildSectionHeader("RETENTION & FILTER POLICIES", isDark),
        _buildRetentionSelector(np, isDark),
        const SizedBox(height: 10),
        _buildQuietHoursCard(np, isDark),
        const SizedBox(height: 16),
        _buildSectionHeader("ENTERPRISE CHANNELS WEBHOOKS", isDark),
        _buildWebhookInputCard(
          "Slack Webhook Integration",
          "Deliver warning bulletins instantly inside Slack channels",
          _slackController,
          "https://hooks.slack.com/services/...",
          const Color(0xFF4A154B),
          isDark,
          () => np.updateSettings(slackWebhookUrlVal: _slackController.text),
        ),
        _buildWebhookInputCard(
          "Discord Alerts Channel",
          "Synchronize bot telemetry live inside server categories",
          _discordController,
          "https://discord.com/api/webhooks/...",
          const Color(0xFF5865F2),
          isDark,
          () => np.updateSettings(discordWebhookUrlVal: _discordController.text),
        ),
        _buildWebhookInputCard(
          "Microsoft Teams Connect",
          "Automate developer alert updates globally inside office networks",
          _teamsController,
          "https://outlook.office.com/webhook/...",
          const Color(0xFF6264A7),
          isDark,
          () => np.updateSettings(teamsWebhookUrlVal: _teamsController.text),
        ),
        _buildWebhookInputCard(
          "Custom Webhook Server",
          "Send POST payload variables dynamically to any custom endpoint API",
          _customWebhookController,
          "https://api.yourdomain.com/v1/event",
          const Color(0xFF10B981),
          isDark,
          () => np.updateSettings(customWebhookUrlVal: _customWebhookController.text),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white24 : Colors.black26,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRetentionSelector(NotificationProvider np, bool isDark) {
    final Map<int, String> options = {
      7: "7 Days",
      30: "30 Days",
      90: "90 Days",
      365: "1 Year",
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Retention Window",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  "Automatically flush historical event logs",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: np.historyRetentionDays,
            dropdownColor: isDark ? const Color(0xFF16161A) : Colors.white,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: Container(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                _triggerHaptic(HapticFeedbackType.light);
                np.updateSettings(historyRetentionDaysVal: newValue);
              }
            },
            items: options.entries.map((entry) {
              return DropdownMenuItem<int>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursCard(NotificationProvider np, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quiet Hours Scheduling",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    "Temporarily mute non-critical alerts",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.black38,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: np.quietHoursEnabled,
                onChanged: (val) {
                  _triggerHaptic(HapticFeedbackType.light);
                  np.updateSettings(quietHoursEnabledVal: val);
                },
                activeColor: const Color(0xFF6366F1),
              ),
            ],
          ),
          if (np.quietHoursEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerField(
                    "START TIME",
                    np.quietHoursStart,
                    (time) {
                      _triggerHaptic(HapticFeedbackType.light);
                      np.updateSettings(quietHoursStartVal: time);
                    },
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerField(
                    "END TIME",
                    np.quietHoursEnd,
                    (time) {
                      _triggerHaptic(HapticFeedbackType.light);
                      np.updateSettings(quietHoursEndVal: time);
                    },
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerField(
    String label,
    String time,
    ValueChanged<String> onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: time,
            dropdownColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: Container(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
            items: [
              "20:00", "21:00", "22:00", "23:00", "00:00", 
              "06:00", "07:00", "08:00", "09:00", "10:00"
            ].map((t) {
              return DropdownMenuItem<String>(value: t, child: Text(t));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWebhookInputCard(
    String label,
    String subtitle,
    TextEditingController controller,
    String placeholder,
    Color accentColor,
    bool isDark,
    VoidCallback onSave,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101014) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16161A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: controller,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: placeholder,
                      hintStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _triggerHaptic(HapticFeedbackType.success);
                  onSave();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: accentColor,
                      content: Text(
                        "Webhook route registered and applied!",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.save_rounded, size: 16, color: accentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum HapticFeedbackType { light, medium, heavy, success }
