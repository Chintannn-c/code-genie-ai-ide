import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/plan_model.dart';
import '../providers/planning_provider.dart';
import '../providers/auth_provider.dart';
import 'diff_viewer.dart';

class PlanningTimeline extends StatelessWidget {
  const PlanningTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PlanningProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!pp.hasActivePlan) return const SizedBox.shrink();

    final plan = pp.currentPlan!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal Orchestration',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      plan.goal,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => pp.clearActivePlan(),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(height: 32),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plan.steps.length,
            onReorder: (oldIndex, newIndex) => pp.reorderSteps(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final step = plan.steps[index];
              return _StepItem(
                key: ValueKey(step.id),
                step: step, 
                isLast: index == plan.steps.length - 1,
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _showAddStepDialog(context, pp),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: Text(
                  'Add Step',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (!plan.isApproved) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final auth = context.read<AuthProvider>();
                    pp.approvePlan(auth.user?.userId ?? 'anonymous', auth.user?.token);
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(
                    'Execute Mission',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddStepDialog(BuildContext context, PlanningProvider pp) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Execution Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Step Title'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              pp.addStep(PlanStep(
                id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                title: titleController.text,
                description: descController.text,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}


class _StepItem extends StatefulWidget {
  final PlanStep step;
  final bool isLast;

  const _StepItem({super.key, required this.step, required this.isLast});

  @override
  State<_StepItem> createState() => _StepItemState();
}

class _StepItemState extends State<_StepItem> {
  bool _showDiff = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = widget.step;
    final isLast = widget.isLast;
    
    return Row(
      key: ValueKey('step_row_${step.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _buildStatusIcon(isDark, step),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: _getLineColor(isDark, step),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _getTextColor(isDark, step),
                      ),
                    ),
                  ),
                  _buildStepActions(context, isDark, step),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                step.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              if (step.diff != null && step.diff!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDiffButton(isDark),
                if (_showDiff) ...[
                  const SizedBox(height: 10),
                  DiffViewer(diff: step.diff!, isDark: isDark),
                ],
              ],
              if (step.toolCall != null) ...[
                const SizedBox(height: 8),
                _buildToolBadge(isDark, step),
              ],
              if (step.logs != null && step.logs!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildConsole(isDark, step),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiffButton(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showDiff = !_showDiff),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showDiff ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              size: 14,
              color: Colors.green,
            ),
            const SizedBox(width: 6),
            Text(
              _showDiff ? 'Hide Changes' : 'Review Changes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBadge(bool isDark, PlanStep step) {
    final action = step.toolCall!['action'] ?? 'action';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF6366F1)),
          const SizedBox(width: 4),
          Text(
            action.toString().toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6366F1),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsole(bool isDark, PlanStep step) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: step.logs!.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            log,
            style: GoogleFonts.firaCode(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStepActions(BuildContext context, bool isDark, PlanStep step) {
    final pp = context.read<PlanningProvider>();
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 16,
        color: isDark ? Colors.white24 : Colors.black12,
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditStepDialog(context, pp, step);
        } else if (value == 'delete') {
          pp.removeStep(step.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16),
              SizedBox(width: 8),
              Text('Edit Step'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditStepDialog(BuildContext context, PlanningProvider pp, PlanStep step) {
    final titleController = TextEditingController(text: step.title);
    final descController = TextEditingController(text: step.description);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Step'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              pp.updateStep(step.id, title: titleController.text, description: descController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isDark, PlanStep step) {
    switch (step.status) {
      case PlanStepStatus.pending:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2),
          ),
        );
      case PlanStepStatus.running:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        );
      case PlanStepStatus.completed:
        return const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22);
      case PlanStepStatus.failed:
        return const Icon(Icons.error_rounded, color: Colors.red, size: 22);
    }
  }

  Color _getLineColor(bool isDark, PlanStep step) {
    return step.status == PlanStepStatus.completed 
        ? Colors.green.withValues(alpha: 0.5) 
        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05));
  }

  Color _getTextColor(bool isDark, PlanStep step) {
    if (step.status == PlanStepStatus.running) return const Color(0xFF6366F1);
    if (step.status == PlanStepStatus.completed) return isDark ? Colors.white70 : Colors.black54;
    return isDark ? Colors.white : Colors.black87;
  }
}
