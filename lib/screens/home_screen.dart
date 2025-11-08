import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});



  final String username = "simone";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue,
              alignment: Alignment.center,
              child: Text("Welcome back ${username[0].toUpperCase() + username.substring(1)}"),
            ),


            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Column(
                children: <Widget>[
                  Container(
                    color: Colors.red,
                    height: 200.0,
                    alignment: Alignment.center,
                    child: Text("Here is your data analyzed"),
                  ),
                  Container( color: Colors.red,
                    height: 200.0,
                    alignment: Alignment.center,
                    child: Text("Here is your data analyzed"),),
                    
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }
}
