import 'package:flutter/material.dart';
import 'package:green/screens/3d_monitor.dart';
import 'screens/home_screen.dart';
import 'dart:developer';
import 'package:camera/camera.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'An App for a Greener Future'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedpage = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(
        key: ValueKey('home_screen'),
      ),
      Monitor3D(
        key: const ValueKey('monitor_screen'),
        onRequestHome: () {
          setState(() {
            _selectedpage = 0;
          });
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _pages[_selectedpage],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _selectedpage,
        onDestinationSelected: (int index) {
          log('tab changed -> $index');
          setState(() {
            _selectedpage = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_outlined),
            selectedIcon: Icon(Icons.monitor),
            label: 'See You in 3D',
          ),
        ],
      ),
    );
  }
}
