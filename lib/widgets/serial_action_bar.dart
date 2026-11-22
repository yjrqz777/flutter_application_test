import 'package:flutter/material.dart';

/// 串口页顶部：一行状态说明 + 主操作按钮。
///
/// 未连接时按钮是「扫描 / 停止扫描」，已连接时变成「断开连接」。
class SerialActionBar extends StatelessWidget {
  const SerialActionBar({
    super.key,
    required this.status,
    required this.connected,
    required this.scanning,
    required this.busy,
    required this.onScanToggle,
    required this.onDisconnect,
  });

  final String status;
  final bool connected;
  final bool scanning;
  final bool busy;
  final VoidCallback onScanToggle;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                connected ? Icons.link : Icons.link_off,
                size: 18,
                color: connected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (connected)
                FilledButton.icon(
                  onPressed: busy ? null : onDisconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('断开连接'),
                )
              else
                FilledButton.icon(
                  onPressed: busy ? null : onScanToggle,
                  icon: Icon(scanning ? Icons.stop : Icons.search),
                  label: Text(scanning ? '停止扫描' : '扫描设备'),
                ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
