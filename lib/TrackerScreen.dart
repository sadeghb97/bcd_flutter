import 'package:file/local.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intervalprogressbar/intervalprogressbar.dart';
import 'SoundTracker.dart';
import 'Constants.dart';
import 'AltTrackerScreen.dart';

class TrackerScreen extends StatefulWidget {
  final LocalFileSystem localFileSystem;

  TrackerScreen({localFileSystem})
      : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  State<StatefulWidget> createState() => new TrackerScreenState();
}

class TrackerScreenState extends State<TrackerScreen> {
  SoundTracker soundTracker;
  String lastResponseMessage;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    soundTracker = new SoundTracker(widget.localFileSystem);
  }

  @override
  Widget build(BuildContext context) {
    soundTracker.setContext(context);

    soundTracker.serverResponseRunnable = (String response){
      setState(() {
        lastResponseMessage = soundTracker.lastResponseMessage;
      });
    };

    soundTracker.updateUiRunnable = (){
      setState(() {});
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: new Center(
            child: new Padding(
              padding: new EdgeInsets.all(8.0),
              child: new Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 24),
                      child: new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          RawMaterialButton(
                            onPressed: () {
                              if(soundTracker.fired) soundTracker.stop();
                              else soundTracker.run();
                            },
                            elevation: 4.0,
                            fillColor: Colors.redAccent.withOpacity(0.8),
                            child: Icon(
                              soundTracker.fired ? Icons.stop : Icons.mic,
                              color: Colors.white,
                              size: 35.0,
                            ),
                            padding: EdgeInsets.all(15.0),
                            shape: CircleBorder(),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      child: buildChart(soundTracker.signalsResult, "Overall", 40, 180, 50),
                      onTap: (){
                        showDialog(
                          context: context,
                          builder: (BuildContext context){
                            return AlertDialog(
                              title: Text("Response"),
                              actions:[
                                FlatButton(
                                  child: Text("Close"),
                                  padding: EdgeInsets.all(0),
                                  onPressed: (){
                                    Navigator.of(context).pop();
                                  },
                                )
                              ],
                              content: SingleChildScrollView(
                                child: Text(
                                  soundTracker.lastResponseMessage != null
                                      ? soundTracker.lastResponseMessage : "None"
                                ),
                              ),
                            );
                          }
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        GestureDetector(
                          child: buildChart(soundTracker.modelsResult[0],
                              DETECTOR_MODELS[0], 18.5, 160, 40),
                          onDoubleTap: (){
                            Navigator.push(
                              context, new CupertinoPageRoute(
                                builder: (context) => new AltTrackerScreen()
                              )
                            );
                          },
                        ),
                        SizedBox(width: 16),
                        buildChart(soundTracker.modelsResult[1],
                            DETECTOR_MODELS[1], 18.5, 160, 40),
                      ],
                    ),
                    SizedBox(height: 20),
                    new Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        buildChart(soundTracker.modelsResult[2],
                            DETECTOR_MODELS[2], 18.5, 160, 40),
                        SizedBox(width: 16),
                        buildChart(soundTracker.modelsResult[3],
                            DETECTOR_MODELS[3], 18.5, 160, 40),
                      ],
                    ),
                  ]
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChart(List signals, String title, double width, double height, int max) {
    double padding = width / 6;

    if(signals == null) signals = [-1, -1, -1, -1, -1, -1];

    Widget chartWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: signals.map<Widget>((value) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: IntervalProgressBar(
            direction: IntervalProgressDirection.vertical,
            max: value >= 0 ? max : 1,
            progress: value >= 0 ? (value * max).round() : 0,
            intervalSize: 2,
            size: Size(width, height),
            highlightColor: Colors.red,
            defaultColor: Colors.grey,
            intervalColor: Colors.transparent,
            intervalHighlightColor: Colors.transparent,
            reverse: true,
            radius: 0));
      }).toList()
    );

    return Column(
      children: <Widget>[
        chartWidget,
        SizedBox(height: 8,),
        new Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700
          ),
        )
      ],
    );
  }
}