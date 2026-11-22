import 'package:flutter/material.dart';

import '../app/theme_controller.dart';

/// 设置页：目前只有主题相关设置。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            children: <Widget>[
              const _SectionTitle('外观'),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('暗色模式'),
                subtitle: const Text('打开后整个应用切换到暗色主题'),
                value: themeController.isDark,
                onChanged: themeController.setDark,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 分组小标题
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
