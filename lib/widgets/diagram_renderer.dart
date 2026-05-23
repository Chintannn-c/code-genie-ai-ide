import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'code_block.dart';

class DiagramRenderer extends StatefulWidget {
  final String diagramCode;
  final bool isStreaming;
  final Color agentColor;

  const DiagramRenderer({
    super.key,
    required this.diagramCode,
    required this.isStreaming,
    required this.agentColor,
  });

  @override
  State<DiagramRenderer> createState() => _DiagramRendererState();
}

class _DiagramRendererState extends State<DiagramRenderer> {
  WebViewController? _controller;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
    if (!kIsWeb && isMobile) {
      try {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.transparent)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                if (mounted) {
                  setState(() {
                    _isWebViewReady = true;
                  });
                  _renderDiagram();
                }
              },
            ),
          )
          ..loadHtmlString(_buildHtml());
      } catch (e) {
        debugPrint("Failed to initialize WebViewController: $e");
        _controller = null;
      }
    }
  }

  @override
  void didUpdateWidget(covariant DiagramRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If stream completed or code changed substantially
    if ((oldWidget.isStreaming && !widget.isStreaming) || 
        (!widget.isStreaming && oldWidget.diagramCode != widget.diagramCode)) {
      if (_isWebViewReady) {
        _renderDiagram();
      }
    }
  }

  String _buildHtml() {
    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
      <script src="https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js"></script>
      <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; background-color: transparent; }
        .mermaid { width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; overflow: auto; padding: 10px; box-sizing: border-box; }
        svg { max-width: 100%; height: auto; }
      </style>
    </head>
    <body>
      <div class="mermaid" id="diagram-container"></div>
      <script>
        mermaid.initialize({
          startOnLoad: false,
          theme: 'dark',
          securityLevel: 'loose',
          fontFamily: 'Inter, sans-serif'
        });
        
        async function renderGraph(graphDefinition) {
          try {
            const container = document.getElementById('diagram-container');
            // Remove code block backticks if they are passed accidentally
            graphDefinition = graphDefinition.replace(/^```mermaid\s*/, '').replace(/```\s*\$/, '');
            const { svg } = await mermaid.render('graphDiv', graphDefinition);
            container.innerHTML = svg;
          } catch (error) {
            document.getElementById('diagram-container').innerHTML = '<div style="color:#ff4b4b;font-family:sans-serif;text-align:center;"><h4>Syntax Error in Diagram</h4><pre style="font-size:10px;color:#ccc;text-align:left;">' + error.message + '</pre></div>';
          }
        }
      </script>
    </body>
    </html>
    ''';
  }

  void _renderDiagram() {
    if (widget.diagramCode.isEmpty) return;
    if (_controller == null) return;
    
    // Clean code for javascript injection
    final cleanCode = widget.diagramCode
      .replaceAll('\\', '\\\\')
      .replaceAll('`', '\\`')
      .replaceAll('\$', '\\\$');
    
    _controller!.runJavaScript("renderGraph(`$cleanCode`);");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isStreaming) {
      return _buildSkeleton();
    }

    if (kIsWeb || _controller == null) {
      return CodeBlock(
        code: widget.diagramCode,
        language: 'mermaid',
        isDark: true,
      );
    }

    return Container(
      height: 350,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.agentColor.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(controller: _controller!),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.agentColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.agentColor.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph_rounded, size: 40, color: widget.agentColor)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 800.ms),
          const SizedBox(height: 16),
          Text(
            "Building Architecture Graph...",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                color: widget.agentColor.withValues(alpha: 0.8),
                duration: 1500.ms,
              ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.agentColor,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat()).fadeIn(delay: (index * 150).ms, duration: 600.ms).then().fadeOut(duration: 600.ms),
            ),
          )
        ],
      ),
    );
  }
}
