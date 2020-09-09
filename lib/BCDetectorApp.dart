import 'package:flutter/material.dart';
import 'TrackerScreen.dart';

class BCDetectorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new MaterialApp(
    debugShowCheckedModeBanner: false,
    home: new TrackerScreen(),
  );
}