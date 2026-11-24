import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 日志级别，控制台里按级别上色
enum LogLevel { info, warn, error }

/// 日志来源：系统事件、发出去的数据、收到数据
enum LogKind { system, tx, rx }

/// 一条日志。
///
/// 内存里保留最近 [AppLog.maxEntries] 条，同时按天写进日志文件，
/// 写文件的那一行格式固定为：
/// `2026-11-24 20:31:02.123 [INFO] [system] [BLE] 文本`
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.kind,
    required this.tag,
    required this.text,
    this.stack,
  });

  final DateTime time;
  final LogLevel level;
  final LogKind kind;

  /// 来源标记，例如 BLE、经典、App
  final String tag;

  final String text;

  /// 出错的调用栈，没有就是 null
  final String? stack;

  /// 时分秒加毫秒，控制台每行最左边显示
  String get timeLabel {
    String two(int value) => value.toString().padLeft(2, '0');
    final String ms = time.millisecond.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.$ms';
  }

  /// 级别文字，只用来显示和写文件
  String get levelLabel => switch (level) {
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };

  /// 来源文字，控制台筛选条用
  String get kindLabel => switch (kind) {
        LogKind.system => '系统',
        LogKind.tx => '发送',
        LogKind.rx => '接收',
      };

  /// 写进文件的一行
  String get fileLine {
    // 一条日志必须占一行，正文里的换行压成空格，否则回读时对不上格式
    final String oneLine = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    return '${_dateLabel(time)} $timeLabel '
        '[${levelLabel}] [${kind.name}] [$tag] $oneLine';
  }

  /// 落盘的全部行：正文一行，后面跟缩进过的调用栈
  List<String> get fileLines {
    final List<String> lines = <String>[fileLine];
    final String? trace = stack;
    if (trace == null) return lines;
    for (final String line in trace.split('\n')) {
      final String trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;
      lines.add('    $trimmed');
    }
    return lines;
  }

  static final RegExp _linePattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}) '
    r'\[(\w+)\] \[(\w+)\] \[([^\]]*)\] (.*)$',
  );

  /// 从文件里的一行还原成日志，格式对不上就返回 null
  static LogEntry? parse(String line) {
    final RegExpMatch? found = _linePattern.firstMatch(line);
    if (found == null) return null;
    final RegExpMatch match = found;

    int group(int index) => int.tryParse(match.group(index) ?? '') ?? 0;

    LogLevel? level;
    for (final LogLevel item in LogLevel.values) {
      if (item.name.toUpperCase() == match.group(8)) {
        level = item;
        break;
      }
    }
    LogKind? kind;
    for (final LogKind item in LogKind.values) {
      if (item.name == match.group(9)) {
        kind = item;
        break;
      }
    }
    if (level == null || kind == null) return null;

    return LogEntry(
      time: DateTime(
        group(1),
        group(2),
        group(3),
        group(4),
        group(5),
        group(6),
        group(7),
      ),
      level: level,
      kind: kind,
      tag: match.group(10) ?? '',
      text: match.group(11) ?? '',
    );
  }
}

/// 全局日志：串口收发、连接状态、出错信息都往这里写。
///
/// 两份数据：内存里一份给控制台页显示，磁盘上按天一份给下次启动回读，
/// 文件放在系统给 App 的临时目录下，保留最近 [keepDays] 天。
class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  /// 内存里最多留多少条，超了从最早的删
  static const int maxEntries = 2000;

  /// 日志文件保留几天
  static const int keepDays = 7;

  /// 单个文件写到多大就不再往下写（串口刷数据时防止把磁盘写满）
  static const int maxFileBytes = 8 * 1024 * 1024;

  /// 启动时最多回读这么多字节，够看最近的记录就行
  static const int _tailBytes = 128 * 1024;

  static const String _folderName = 'multifunction_debug_tool_logs';

  /// 等级设置存在同目录的小文件里，下次启动还沿用
  static const String _settingsFile = 'settings.conf';

  final List<LogEntry> _entries = <LogEntry>[];

  Directory? _directory;

  /// 写文件串成一条链，保证顺序，也不阻塞界面
  Future<void> _writeQueue = Future<void>.value();

  String _currentDay = '';
  int _writtenBytes = 0;
  bool _fileFull = false;

  LogLevel _minLevel = LogLevel.info;

  /// 内存里的日志，最新的在最后
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  /// 日志文件所在目录，初始化失败时为 null
  String? get directoryPath => _directory?.path;

  /// 当前的记录等级：低于它的日志既不进内存也不写文件
  LogLevel get minLevel => _minLevel;

  /// 改记录等级，同时存下来给下次启动用
  Future<void> setMinLevel(LogLevel level) async {
    if (_minLevel == level) return;
    _minLevel = level;
    await _saveSettings();
    add(LogLevel.warn, LogKind.system, 'App', '记录等级改为 ${level.name}');
    notifyListeners();
  }

  /// 启动时调一次：建目录、读等级设置、把今天已有的记录读回内存、清掉过期文件。
  Future<void> init() async {
    try {
      final Directory directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$_folderName',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _directory = directory;
      await _loadSettings();
      await _loadRecent();
      await _deleteOldFiles();
      add(
        LogLevel.info,
        LogKind.system,
        'App',
        '控制台已启动，日志目录：${directory.path}',
      );
    } catch (error) {
      add(LogLevel.warn, LogKind.system, 'App', '日志功能初始化失败：$error');
    }
  }

  /// 记一条系统事件；带「失败」「错误」这类字眼的按错误级别记
  void addSystem(String tag, String text, {String? stack}) {
    final bool isError = stack != null ||
        text.contains('失败') ||
        text.contains('错误') ||
        text.contains('异常') ||
        text.contains('拒绝') ||
        text.contains('出错');
    add(
      isError ? LogLevel.error : LogLevel.info,
      LogKind.system,
      tag,
      text,
      stack: stack,
    );
  }

  /// 记一条日志：进内存、写文件、通知界面刷新
  void add(
    LogLevel level,
    LogKind kind,
    String tag,
    String text, {
    String? stack,
  }) {
    if (text.isEmpty) return;
    // 低于当前等级的日志直接丢掉，不占内存也不落盘
    if (level.index < _minLevel.index) return;

    final LogEntry entry = LogEntry(
      time: DateTime.now(),
      level: level,
      kind: kind,
      tag: tag,
      text: text,
      stack: stack,
    );

    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    _persist(entry);
    notifyListeners();
  }

  /// 清空内存记录并删掉所有日志文件
  Future<void> clear() async {
    _entries.clear();
    notifyListeners();

    final Directory? directory = _directory;
    if (directory == null) return;
    try {
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is! File) continue;
        // 等级设置留着，只删日志
        if (entity.uri.pathSegments.last == _settingsFile) continue;
        await entity.delete();
      }
      _writtenBytes = 0;
      _fileFull = false;
    } catch (_) {
      // 删不掉不影响界面，下次启动还能再清
    }
  }

  /// 排队写文件；写失败就丢掉这一行，不影响界面
  void _persist(LogEntry entry) {
    final Directory? directory = _directory;
    if (directory == null) return;

    final String day = _dateLabel(entry.time);
    if (day != _currentDay) {
      _currentDay = day;
      _writtenBytes = 0;
      _fileFull = false;
    }
    if (_fileFull) return;

    final String content = '${entry.fileLines.join('\n')}\n';
    final int lineBytes = utf8.encode(content).length;
    if (_writtenBytes + lineBytes > maxFileBytes) {
      _fileFull = true;
      _write(directory, day, '[日志超过 ${maxFileBytes ~/ (1024 * 1024)}MB，今天的文件不再写入]\n');
      return;
    }
    _writtenBytes += lineBytes;
    _write(directory, day, content);
  }

  void _write(Directory directory, String day, String content) {
    final File file =
        File('${directory.path}${Platform.pathSeparator}log-$day.log');
    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString(content, mode: FileMode.append);
      } catch (_) {
        // 磁盘满、权限被拒之类，丢掉这一行继续跑
      }
    });
  }

  /// 读等级设置；文件不在就保持默认的 info
  Future<void> _loadSettings() async {
    final Directory? directory = _directory;
    if (directory == null) return;
    try {
      final File file =
          File('${directory.path}${Platform.pathSeparator}$_settingsFile');
      if (!await file.exists()) return;
      for (final String line in (await file.readAsString()).split('\n')) {
        if (!line.startsWith('minLevel=')) continue;
        final String value = line.substring('minLevel='.length).trim();
        for (final LogLevel level in LogLevel.values) {
          if (level.name == value) _minLevel = level;
        }
      }
    } catch (_) {
      // 读不出来就用默认等级
    }
  }

  /// 存等级设置
  Future<void> _saveSettings() async {
    final Directory? directory = _directory;
    if (directory == null) return;
    try {
      await File('${directory.path}${Platform.pathSeparator}$_settingsFile')
          .writeAsString('minLevel=${_minLevel.name}\n');
    } catch (_) {
      // 存不下来只影响下次启动，不影响这次
    }
  }

  /// 把今天已有的日志读回内存，只读文件尾巴
  Future<void> _loadRecent() async {
    final Directory? directory = _directory;
    if (directory == null) return;

    final File file = File(
      '${directory.path}${Platform.pathSeparator}log-${_dateLabel(DateTime.now())}.log',
    );
    if (!await file.exists()) return;

    _writtenBytes = await file.length();
    _currentDay = _dateLabel(DateTime.now());
    for (final String line in await _tailLines(file)) {
      final LogEntry? entry = LogEntry.parse(line);
      if (entry == null) continue;
      // 等级调高过的话，旧的低等级记录也不再显示
      if (entry.level.index < _minLevel.index) continue;
      _entries.add(entry);
    }
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
  }

  /// 读文件最后 [_tailBytes] 字节并拆成行
  Future<List<String>> _tailLines(File file) async {
    final int length = await file.length();
    final int start = length > _tailBytes ? length - _tailBytes : 0;

    final RandomAccessFile reader = await file.open();
    try {
      await reader.setPosition(start);
      final String text = utf8.decode(
        await reader.read(length - start),
        allowMalformed: true,
      );
      final List<String> lines = text.split('\n');
      if (start > 0 && lines.isNotEmpty) {
        lines.removeAt(0); // 第一行大概率被截断，丢掉
      }
      return lines.where((String line) => line.isNotEmpty).toList();
    } finally {
      await reader.close();
    }
  }

  /// 删掉超过 [keepDays] 天的日志文件
  Future<void> _deleteOldFiles() async {
    final Directory? directory = _directory;
    if (directory == null) return;

    final DateTime now = DateTime.now();
    final DateTime limit = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: keepDays));

    try {
      await for (final FileSystemEntity entity in directory.list()) {
        if (entity is! File) continue;
        final String name = entity.uri.pathSegments.last;
        if (!name.startsWith('log-') || !name.endsWith('.log')) continue;
        final DateTime? day =
            _parseDate(name.substring(4, name.length - 4));
        if (day == null) continue;
        if (day.isBefore(limit)) await entity.delete();
      }
    } catch (_) {
      // 清理失败不影响使用
    }
  }
}

/// 文件名和文件行里用的日期：2026-11-24
String _dateLabel(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}';
}

DateTime? _parseDate(String text) {
  final List<String> parts = text.split('-');
  if (parts.length != 3) return null;
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
