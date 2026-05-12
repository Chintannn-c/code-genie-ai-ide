import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ModelSelector extends StatelessWidget {
  final bool isDark;

  const ModelSelector({super.key, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value.startsWith('model:')) {
          cp.setModel(value.replaceFirst('model:', ''));
        } else {
          cp.setProvider(value);
        }
      },
      itemBuilder: (context) => [
        _buildSectionHeader('PROVIDERS'),
        _buildItem(
          value: 'gemini',
          label: 'Google Gemini',
          icon: Icons.flare_rounded,
          isSelected: cp.selectedProvider == 'gemini',
        ),
        _buildItem(
          value: 'openrouter',
          label: 'OpenRouter (Claude/GPT)',
          icon: Icons.hub_rounded,
          isSelected: cp.selectedProvider == 'openrouter',
        ),
        if (cp.selectedProvider == 'openrouter') ...[
          const PopupMenuDivider(),
          _buildSectionHeader('FREE MODELS'),
          _buildItem(
            value: 'model:meta-llama/llama-3.3-70b-instruct:free',
            label: 'Llama 3.3 (70B)',
            icon: Icons.psychology_rounded,
            isSelected: cp.selectedModel == 'meta-llama/llama-3.3-70b-instruct:free',
          ),
          _buildItem(
            value: 'model:google/gemini-2.0-flash-exp:free',
            label: 'Gemini 2.0 Flash',
            icon: Icons.bolt_rounded,
            isSelected: cp.selectedModel == 'google/gemini-2.0-flash-exp:free',
          ),
        ],
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getProviderIcon(cp.selectedProvider),
              size: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              _getProviderName(cp.selectedProvider).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded, 
              size: 14, 
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSectionHeader(String title) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 30,
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem({
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF6366F1)),
          ],
        ],
      ),
    );
  }

  IconData _getProviderIcon(String provider) {
    switch (provider) {
      case 'openrouter':
        return Icons.hub_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _getProviderName(String provider) {
    switch (provider) {
      case 'openrouter':
        return 'OPENROUTER';
      default:
        return 'GEMINI';
    }
  }
}
