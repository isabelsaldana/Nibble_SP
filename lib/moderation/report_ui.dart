import 'package:flutter/material.dart';
import 'report_service.dart';

class ReportUI {
  static const reasons = <String>[
    'Harassment or bullying',
    'Hate speech',
    'Spam or scam',
    'Sexual content',
    'Violence or threats',
    'Misinformation',
    'Other',
  ];

  static Future<void> openReportSheet(
    BuildContext context, {
    required ReportTarget target,
    String? title,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title ?? 'Report'),
                subtitle: const Text('Help keep Nibble safe'),
              ),
              const Divider(height: 1),
              for (final r in reasons)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen == null) return;

    String? details;
    if (chosen == 'Other') {
      details = await _askDetails(context, optional: false);
      if (details == null) return; // cancelled
    } else {
      details = await _askDetails(context, optional: true); // can skip
      // if user hits "Skip", it returns '' and we store null
    }

    try {
      await ReportService.submit(target: target, reason: chosen, details: details);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report was submitted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to report: $e')),
      );
    }
  }

  static Future<String?> _askDetails(BuildContext context, {required bool optional}) async {
    final c = TextEditingController();

    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(optional ? 'Add details (optional)' : 'Tell us what happened'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a short note…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, optional ? '' : null),
            child: Text(optional ? 'Skip' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    return res;
  }
}

