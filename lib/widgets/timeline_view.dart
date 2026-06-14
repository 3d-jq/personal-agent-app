import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../core/agent_colors.dart';

class TimelineView extends StatelessWidget {
  final List<TimelineStep> steps;
  final AgentColors nc;
  const TimelineView({super.key, required this.steps, required this.nc});

  @override
  Widget build(BuildContext context) {
    final processSteps = steps.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(processSteps.length, (i) {
        final step = processSteps[i];
        final isLast = i == processSteps.length - 1;
        final isRunning = step.status == TimelineStepStatus.running;
        final isDone = step.status == TimelineStepStatus.done;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 12, height: 12,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? nc.success
                            : isRunning ? nc.textPrimary
                            : nc.textDisabled,
                        border: !isDone && !isRunning
                            ? Border.all(color: nc.divider, width: 1.5)
                            : null,
                      ),
                      child: isRunning
                          ? const Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(strokeWidth: 1.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : isDone
                              ? const Icon(Icons.check, size: 8, color: Colors.white)
                              : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: nc.divider,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDone ? nc.textPrimary
                          : isRunning ? nc.textPrimary
                          : nc.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
