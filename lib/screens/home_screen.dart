import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});



  final String username = "simone";
  
  @override
  Widget build(BuildContext context) {

    double width = MediaQuery.sizeOf(context).width;
    double height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: width,
        height: height * 0.3,
        color: Colors.green,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, $username!',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Here's your activity summary for today.",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),

      SizedBox(height: 16),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: width * 0.4,
            height: height * 0.2,
            color: Colors.lightGreen,
            child: Center(
              child:Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Plants Watered: 3',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'New Tasks: 2',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: width * 0.4,
            height: height * 0.2,
            color: Colors.lightGreen,
            child: Center(
              child:Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Water Usage: 12L',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Light Exposure: 6h',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      SizedBox(height: 16),

      // Articles section
      Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text("Articles", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
        SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: width * 0.6,
              height: height * 0.25,
              margin: EdgeInsets.all(8),
              color: Colors.greenAccent,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caring for Your Indoor Plants',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Learn the best practices for watering, lighting, and maintaining your indoor plants to keep them healthy and thriving.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: width * 0.6,
              height: height * 0.25,
              margin: EdgeInsets.all(8),
              color: Colors.greenAccent,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 10 Low-Maintenance Plants',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Discover a selection of low-maintenance plants that are perfect for busy individuals or those new to plant care.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
      ]),
      )]
      )
    ],
  ),
),
    );
  }
}
