import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CriticCard extends StatefulWidget {
  final Map<String, dynamic> critique;
  final bool isLoading;
  final VoidCallback onReanalyze;

  const CriticCard({
    super.key,
    required this.critique,
    required this.isLoading,
    required this.onReanalyze,
  });

  @override
  State<CriticCard> createState() => _CriticCardState();
}

class _CriticCardState extends State<CriticCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );
    _animationController.value = 1.0; // Initially expanded
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF38BA8).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF38BA8)),
              strokeWidth: 3,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Critic analyzing code...',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scanning security, performance, and best practices...',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFA6ADC8).withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final score = widget.critique['overall_score'] ?? 7;
    final summary = widget.critique['summary'] ?? 'No review summary provided.';
    final securityIssues = List<Map<String, dynamic>>.from(widget.critique['security_issues'] ?? []);
    final performanceNotes = List<Map<String, dynamic>>.from(widget.critique['performance_notes'] ?? []);
    final suggestions = List<Map<String, dynamic>>.from(widget.critique['suggestions'] ?? []);

    // Determine color based on overall score
    Color scoreColor = const Color(0xFFA6E3A1); // Green
    if (score < 5) {
      scoreColor = const Color(0xFFF38BA8); // Red
    } else if (score < 8) {
      scoreColor = const Color(0xFFF9E2AF); // Yellow
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(_isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: scoreColor, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$score',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Critic Review & Security Audit',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFA6ADC8).withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action buttons
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFA6ADC8)),
                    tooltip: 'Re-analyze Code',
                    onPressed: widget.onReanalyze,
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFA6ADC8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1, color: Color(0xFF313244)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Security Issues Section
                      _buildSectionHeader(
                        context,
                        'Security Audits',
                        Icons.security_rounded,
                        const Color(0xFFF38BA8),
                        securityIssues.length,
                      ),
                      const SizedBox(height: 8),
                      if (securityIssues.isEmpty)
                        _buildEmptyLabel('No security vulnerabilities detected.')
                      else
                        ...securityIssues.map((issue) {
                          final severity = issue['severity']?.toString().toUpperCase() ?? 'LOW';
                          final desc = issue['description'] ?? '';
                          final line = issue['line'] ?? 0;

                          Color sevColor = const Color(0xFFA6E3A1);
                          if (severity == 'HIGH') {
                            sevColor = const Color(0xFFF38BA8);
                          } else if (severity == 'MEDIUM') {
                            sevColor = const Color(0xFFF9E2AF);
                          }

                          return _buildIssueTile(
                            context,
                            'Line $line — $desc',
                            severity,
                            sevColor,
                          );
                        }),
                      const SizedBox(height: 20),

                      // Performance Section
                      _buildSectionHeader(
                        context,
                        'Performance Benchmarks',
                        Icons.speed_rounded,
                        const Color(0xFF89B4FA),
                        performanceNotes.length,
                      ),
                      const SizedBox(height: 8),
                      if (performanceNotes.isEmpty)
                        _buildEmptyLabel('No performance issues found.')
                      else
                        ...performanceNotes.map((note) {
                          final impact = note['impact']?.toString().toUpperCase() ?? 'LOW';
                          final desc = note['description'] ?? '';

                          Color impColor = const Color(0xFFA6E3A1);
                          if (impact == 'HIGH') {
                            impColor = const Color(0xFFF38BA8);
                          } else if (impact == 'MEDIUM') {
                            impColor = const Color(0xFFF9E2AF);
                          }

                          return _buildIssueTile(
                            context,
                            desc,
                            'IMPACT: $impact',
                            impColor,
                          );
                        }),
                      const SizedBox(height: 20),

                      // Suggestions Section
                      _buildSectionHeader(
                        context,
                        'Improvement Suggestions',
                        Icons.tips_and_updates_rounded,
                        const Color(0xFFFAB387),
                        suggestions.length,
                      ),
                      const SizedBox(height: 8),
                      if (suggestions.isEmpty)
                        _buildEmptyLabel('Code follows active best practices.')
                      else
                        ...suggestions.map((suggestion) {
                          final desc = suggestion['description'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF11111B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFFAB387),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    desc,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFCDD6F4),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 30.0, top: 4, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: const Color(0xFFA6ADC8).withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildIssueTile(
    BuildContext context,
    String desc,
    String badgeText,
    Color badgeColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: badgeColor,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.outfit(
                color: const Color(0xFFCDD6F4),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
