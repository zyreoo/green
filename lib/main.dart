import 'package:flutter/material.dart';
import 'package:green/screens/3dMonitor.dart';
import 'package:green/screens/profile.dart';
import 'package:green/screens/tasks.dart';
import 'screens/home_screen.dart';
import 'dart:developer';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ScreenSize extends StatelessWidget {
  const ScreenSize({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      body: Center(
        child: Text('Width: $width, Height: $height'),
      ),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedpage = 0;

final List<Widget> _pages = [
  HomeScreen(), 
  Monitor3D(), 
  Tasks(),
  Profile()
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedpage],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedpage,
        onTap: (int index) {
          log("tapped");
          setState(() {
            _selectedpage = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.monitor), label: '3D Monitor',backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks', backgroundColor: Colors.black),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile",backgroundColor: Colors.black),
        ],
      ),
    ); 
    }

  
}
