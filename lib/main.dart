import 'package:flutter/material.dart';

import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 当前主题模式（初始为跟随系统）
  ThemeMode _themeMode = ThemeMode.system;

  // 切换主题：三态循环（系统 -> 亮色 -> 暗色 -> 系统）
  void _toggleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: MyHomePage(
        title: 'Flutter Demo Home Page',
        onToggleTheme: _toggleThemeMode,
      ),
      debugShowCheckedModeBanner: false, // 是否显示右上角 DEBUG 横幅
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.onToggleTheme});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final VoidCallback onToggleTheme;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    debugPrint(_counter.toString());
  }
    void _cleanCounter() {
    setState(() {
      _counter = 0;
    });
    debugPrint(_counter.toString());
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // leadingWidth: 80,
        leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_sharp),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.abc),
            onPressed: _cleanCounter,
          ),
        ],
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text(
              '你好',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
