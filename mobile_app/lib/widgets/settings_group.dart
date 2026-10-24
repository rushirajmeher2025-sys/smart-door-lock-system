import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? footer;

  const SettingsGroup({super.key, required this.title, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 54));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(title.toUpperCase(), style: AppTheme.label()),
        ),
        Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.hairline),
          ),
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(footer!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45)),
          ),
      ],
    );
  }
}
