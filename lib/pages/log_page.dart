import 'package:flutter/material.dart';

import '../logging/app_log.dart';

/// 控制台：类似浏览器开发者工具的那种日志列表。
///
/// 内容和写进文件的一致：连接、断开、扫描、服务发现、出错这些系统事件，
/// 加上收发的数据。顶部按来源筛选，右上角能改记录等级、清空日志。
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  /// null 表示不按来源筛选
  LogKind? _kind;

  Future<void> _confirmClear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('内存里的记录和磁盘上的日志文件都会删掉，删了找不回。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLog.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLog.instance,
      builder: (BuildContext context, Widget? child) {
        final List<LogEntry> all = AppLog.instance.entries;
        final List<LogEntry> visible = _kind == null
            ? all
            : all.where((LogEntry entry) => entry.kind == _kind).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('控制台'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '清空日志',
                onPressed: _confirmClear,
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              _buildFilters(context),
              const Divider(height: 1),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('还没有日志'))
                    : _buildList(visible),
              ),
              const Divider(height: 1),
              _buildFooter(context, all.length),
            ],
          ),
        );
      },
    );
  }

  /// 筛选条：来源用胶囊按钮，右端跟一个同款的等级入口
  Widget _buildFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          _buildChip(null, '全部'),
          const SizedBox(width: 8),
          for (final LogKind kind in LogKind.values) ...<Widget>[
            _buildChip(kind, _kindLabel(kind)),
            const SizedBox(width: 8),
          ],
          SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 16,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          _buildLevelChip(context),
        ],
      ),
    );
  }

  Widget _buildChip(LogKind? kind, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _kind == kind,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _kind = kind),
    );
  }

  /// 记录等级入口：做成和筛选胶囊同款，点开是等级菜单
  Widget _buildLevelChip(BuildContext context) {
    final LogLevel current = AppLog.instance.minLevel;
    final ThemeData theme = Theme.of(context);
    return PopupMenuButton<LogLevel>(
      tooltip: '记录等级',
      initialValue: current,
      onSelected: (LogLevel level) => AppLog.instance.setMinLevel(level),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<LogLevel>>[
        for (final LogLevel level in LogLevel.values)
          PopupMenuItem<LogLevel>(
            value: level,
            child: Row(
              children: <Widget>[
                Icon(
                  level == current ? Icons.check : Icons.filter_alt_outlined,
                  size: 18,
                  color: level == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(_levelLabel(level)),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(
          Icons.filter_alt_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        label: Text('等级：${_levelLabel(current)}'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
    );
  }

  Widget _buildList(List<LogEntry> visible) {
    // reverse: true 让最新的记录贴在底部，新日志进来不用手动滚
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: visible.length,
      itemBuilder: (BuildContext context, int index) {
        final LogEntry entry = visible[visible.length - 1 - index];
        return _LogRow(entry: entry);
      },
    );
  }

  Widget _buildFooter(BuildContext context, int total) {
    final ThemeData theme = Theme.of(context);
    final String directory = AppLog.instance.directoryPath ?? '未初始化';
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '共 $total 条 · 文件保留最近 ${AppLog.keepDays} 天',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            '目录：$directory',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static String _kindLabel(LogKind kind) => switch (kind) {
        LogKind.system => '系统',
        LogKind.tx => '发送',
        LogKind.rx => '接收',
      };

  static String _levelLabel(LogLevel level) => switch (level) {
        LogLevel.info => '全部',
        LogLevel.warn => '警告以上',
        LogLevel.error => '仅错误',
      };
}

/// 一行日志：时间、来源、内容；出错的行整行标红，带调用栈的可以展开看
class _LogRow extends StatefulWidget {
  const _LogRow({required this.entry, super.key});

  final LogEntry entry;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LogEntry entry = widget.entry;
    final Color color = switch (entry.level) {
      LogLevel.info => theme.colorScheme.onSurfaceVariant,
      LogLevel.warn => theme.colorScheme.tertiary,
      LogLevel.error => theme.colorScheme.error,
    };
    final TextStyle? small = theme.textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace', color: color);
    final String? stack = entry.stack;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.tag}·${entry.kindLabel}', style: small),
              const SizedBox(width: 8),
              Expanded(child: SelectableText(entry.text, style: small)),
              if (stack != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: _expanded ? '收起调用栈' : '查看调用栈',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
          if (_expanded && stack != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
              child: SelectableText(
                stack,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
