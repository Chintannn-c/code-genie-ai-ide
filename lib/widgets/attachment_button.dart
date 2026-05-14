import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:google_fonts/google_fonts.dart';

class AttachmentButton extends StatelessWidget {
  final Function(List<fp.PlatformFile>) onFilesSelected;
  final bool isDark;
  final bool isLoading;

  const AttachmentButton({
    super.key,
    required this.onFilesSelected,
    this.isDark = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, -110), // Position above the icon
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      onSelected: (value) {
        if (value == 'photo') {
          _pickFiles(isImage: true);
        } else {
          _pickFiles(isImage: false);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem(
          value: 'photo',
          icon: Icons.image_rounded,
          label: 'Upload Photo',
          subtitle: 'Screenshots & OCR',
        ),
        _buildPopupItem(
          value: 'file',
          icon: Icons.description_rounded,
          label: 'Upload File',
          subtitle: 'Source code & Docs',
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
              )
            : Icon(
                Icons.attach_file_rounded,
                size: 22,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem({
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles({required bool isImage}) async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // IMPORTANT for Web support
        type: isImage ? fp.FileType.image : fp.FileType.any, // Allow any for files to be safe
      );

      if (result != null && result.files.isNotEmpty) {
        onFilesSelected(result.files);
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }
}
