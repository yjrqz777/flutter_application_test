import 'package:flutter/material.dart';

import '../app/app_info.dart';

/// 关于页：应用名、版本、说明和功能列表。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: <Widget>[
          Center(
            child: Icon(
              Icons.developer_board,
              size: 72,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppInfo.appName,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'v${AppInfo.version} · 构建 ${AppInfo.buildNumber}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          Text(AppInfo.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('主要功能', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final String feature in AppInfo.features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(feature, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
