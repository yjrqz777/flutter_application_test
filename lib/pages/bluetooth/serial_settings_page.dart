import 'package:flutter/material.dart';

import '../../bluetooth/serial_view_settings.dart';

/// 串口调试页的子设置：选择调试页模板，控制各个显示模块和快捷指令。
class SerialSettingsPage extends StatefulWidget {
  const SerialSettingsPage({super.key, required this.settings});

  final SerialViewSettings settings;

  @override
  State<SerialSettingsPage> createState() => _SerialSettingsPageState();
}

class _SerialSettingsPageState extends State<SerialSettingsPage> {
  final TextEditingController _commandController = TextEditingController();

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  void _addCommand() {
    widget.settings.addQuickCommand(_commandController.text);
    _commandController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('串口页设置')),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (BuildContext context, Widget? child) {
          final SerialViewSettings settings = widget.settings;
          final ThemeData theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              const _SectionTitle('调试页类型'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<SerialViewMode>(
                  segments: const <ButtonSegment<SerialViewMode>>[
                    ButtonSegment<SerialViewMode>(
                      value: SerialViewMode.normal,
                      label: Text('普通调试页'),
                      icon: Icon(Icons.article_outlined),
                    ),
                    ButtonSegment<SerialViewMode>(
                      value: SerialViewMode.custom,
                      label: Text('自定义调试页'),
                      icon: Icon(Icons.tune),
                    ),
                  ],
                  selected: <SerialViewMode>{settings.mode},
                  onSelectionChanged: (Set<SerialViewMode> selection) =>
                      settings.setMode(selection.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  settings.isCustom
                      ? '自定义：显示模块自由开关'
                      : '普通：固定模板，收发和方向标签常显，时间戳、字节计数可关',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const Divider(height: 24),
              const _SectionTitle('显示模块'),
              SwitchListTile(
                secondary: const Icon(Icons.schedule),
                title: const Text('时间戳'),
                subtitle: const Text('每条记录显示收发时间'),
                value: settings.showTimestamp,
                onChanged: settings.setShowTimestamp,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.data_usage),
                title: const Text('收发字节计数'),
                subtitle: const Text('顶部显示累计发送 / 接收字节数'),
                value: settings.showByteCount,
                onChanged: settings.setShowByteCount,
              ),
              if (settings.isCustom) ...<Widget>[
                SwitchListTile(
                  secondary: const Icon(Icons.label_outline),
                  title: const Text('方向标签'),
                  subtitle: const Text('显示发送 / 接收 / 提示标记'),
                  value: settings.showDirection,
                  onChanged: settings.setShowDirection,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.code),
                  title: const Text('HEX 视图'),
                  subtitle: const Text('记录内容按十六进制显示'),
                  value: settings.showHexView,
                  onChanged: settings.setShowHexView,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt),
                  title: const Text('快捷指令栏'),
                  subtitle: const Text('输入框上方显示常用指令按钮'),
                  value: settings.showQuickCommands,
                  onChanged: settings.setShowQuickCommands,
                ),
              ],
              if (settings.isCustom && settings.showQuickCommands) ...<Widget>[
                const Divider(height: 24),
                const _SectionTitle('快捷指令'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _commandController,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '新增一条，例如 AT+GMR',
                          ),
                          onSubmitted: (_) => _addCommand(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addCommand,
                        icon: const Icon(Icons.add),
                        tooltip: '添加',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final String command in settings.quickCommands)
                        InputChip(
                          label: Text(command),
                          onDeleted: () =>
                              settings.removeQuickCommand(command),
                        ),
                    ],
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
