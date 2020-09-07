import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'SoundTracker.dart';

void main() {
  return runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: new Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: new TrackerScreen(),
          ),
        ),
      ),
    );
  }
}

class TrackerScreen extends StatefulWidget {
  final LocalFileSystem localFileSystem;

  TrackerScreen({localFileSystem})
      : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  State<StatefulWidget> createState() => new TrackerScreenState();
}

class TrackerScreenState extends State<TrackerScreen> {
  SoundTracker soundTracker;
  FlutterAudioRecorder _recorder;
  Recording _current;
  RecordingStatus _currentStatus = RecordingStatus.Unset;
  String requestStatus = "";
  AudioPlayer audioPlayer = new AudioPlayer();
  List<bool> isSelected = [false, true, false];
  bool waiting = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _init();
    soundTracker = new SoundTracker(widget.localFileSystem);
  }

  @override
  Widget build(BuildContext context) {
    soundTracker.setContext(context);
    soundTracker.serverResponseRunnable = (String response){
      setState(() {
        requestStatus = response;
      });
    };

    return new Center(
      child: new Padding(
        padding: new EdgeInsets.all(8.0),
        child: new Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 12),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 100,
                      height: 45,
                      child: new FlatButton(
                        onPressed: () {
                          switch (_currentStatus) {
                            case RecordingStatus.Initialized:
                              {
                                _start();
                                break;
                              }
                            case RecordingStatus.Recording:
                              {
                                _pause();
                                break;
                              }
                            case RecordingStatus.Paused:
                              {
                                _resume();
                                break;
                              }
                            case RecordingStatus.Stopped:
                              {
                                _init();
                                break;
                              }
                            default:
                              break;
                          }
                        },
                        child: _buildText(_currentStatus),
                        color: Colors.lightBlue,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    SizedBox(
                      width: 100,
                      height: 45,
                      child: new FlatButton(
                        onPressed:
                        _currentStatus != RecordingStatus.Unset ? _stop : null,
                        child:
                        new Text("Stop", style: TextStyle(color: Colors.white)),
                        color: Colors.blueAccent.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    SizedBox(
                      width: 100,
                      height: 45,
                      child: new FlatButton(
                        onPressed: () {
                          if(_current.status == RecordingStatus.Stopped)
                            onPlayAudio(_current.path);
                        },
                        child:
                        new Text("Play", style: TextStyle(color: Colors.white)),
                        color: _currentStatus == RecordingStatus.Stopped ?
                          Colors.lightBlue : Colors.lightBlue.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 12),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 150,
                      height: 45,
                      child: new FlatButton(
                        onPressed: () {
                          if(soundTracker.fired) soundTracker.stop();
                          else soundTracker.run();
                        },
                        child: Text("Tick", style: TextStyle(
                          color: Colors.white
                        )),
                        color: Colors.lightBlue,
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      height: 45,
                      child: new FlatButton(
                        onPressed: () {
                          if(soundTracker.lastRecordedPath != null)
                            onPlayAudio(soundTracker.lastRecordedPath);
                        },
                        child: Text("Play", style: TextStyle(
                            color: Colors.white
                        )),
                        color: Colors.lightBlue,
                      ),
                    ),
                  ],
                ),
              ),
              new Text("Status : $_currentStatus"),
              new Text(
                  "Audio recording duration : ${_current?.duration.toString()}"),
              Padding(
                padding: const EdgeInsets.only(top: 32.0),
                child: new ToggleButtons(
                  children: <Widget>[
                    SizedBox(
                      child: Icon(Icons.done),
                      width: 100,
                    ),
                    SizedBox(
                      child: Icon(Icons.device_unknown),
                      width: 100,
                    ),
                    SizedBox(
                      child: Icon(Icons.close),
                      width: 100,
                    ),
                  ],
                  selectedColor: Colors.brown,
                  fillColor: Colors.orangeAccent,
                  isSelected: isSelected,
                  onPressed: (index) {
                    setState(() {
                      if(isSelected[index]) return;
                      for(int i=0; isSelected.length>i; i++){
                        if(i == index) isSelected[i] = true;
                        else isSelected[i] = false;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 12),
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 200,
                      height: 75,
                      child: new FlatButton(
                        onPressed: requestServer,
                        child: Text(
                          "Request"
                        ),
                        color: (_currentStatus == RecordingStatus.Stopped && !waiting) ?
                          Colors.pinkAccent : Colors.pink.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              new Text("Request: " + (requestStatus.isNotEmpty ? requestStatus : "None")),
            ]),
      ),
    );
  }

  _init() async {
    print("QQQ_init");
    try {
      if (await FlutterAudioRecorder.hasPermissions) {
        String customPath = '/flutter_audio_recorder_';
        io.Directory appDocDirectory;
//        io.Directory appDocDirectory = await getApplicationDocumentsDirectory();
        if (io.Platform.isIOS) {
          appDocDirectory = await getApplicationDocumentsDirectory();
        } else {
          appDocDirectory = await getExternalStorageDirectory();
        }

        // can add extension like ".mp4" ".wav" ".m4a" ".aac"
        customPath = appDocDirectory.path +
            customPath +
            DateTime.now().millisecondsSinceEpoch.toString();

        // .wav <---> AudioFormat.WAV
        // .mp4 .m4a .aac <---> AudioFormat.AAC
        // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
        _recorder =
            FlutterAudioRecorder(customPath, audioFormat: AudioFormat.WAV, sampleRate: 44100);

        await _recorder.initialized;
        // after initialization
        var current = await _recorder.current(channel: 0);
        print(current);
        // should be "Initialized", if all working fine
        setState(() {
          _current = current;
          _currentStatus = current.status;
          print(_currentStatus);
        });
      } else {
        Scaffold.of(context).showSnackBar(
            new SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  _start() async {
    print("QQQ_start");
    try {
      await _recorder.start();
      var recording = await _recorder.current(channel: 0);
      setState(() {
        _current = recording;
      });

      const tick = const Duration(milliseconds: 50);
      new Timer.periodic(tick, (Timer t) async {
        if (_currentStatus == RecordingStatus.Stopped) {
          t.cancel();
        }

        var current = await _recorder.current(channel: 0);
        // print(current.status);
        setState(() {
          _current = current;
          _currentStatus = _current.status;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  _resume() async {
    print("QQQ_resume");
    await _recorder.resume();
    setState(() {});
  }

  _pause() async {
    print("QQQ_pause");
    await _recorder.pause();
    setState(() {});
  }

  _stop() async {
    print("QQQ_stop");
    var result = await _recorder.stop();
    print("Stop recording: ${result.path}");
    print("Stop recording: ${result.duration}");
    File file = widget.localFileSystem.file(result.path);
    print("File length: ${await file.length()}");
    setState(() {
      _current = result;
      _currentStatus = _current.status;
    });
  }

  requestServer() async {
    if(_currentStatus != RecordingStatus.Stopped || waiting) return;

    try {
      FormData formData = FormData.fromMap({
        "name": "Sadegh",
        "sound": await MultipartFile.fromFile(
          //"/storage/emulated/0/nope3.wav",
            _current.path,
            filename: "newsignal.wav"
        ),
        "type": isSelected[0] ? "cry" :
        (isSelected[2] ? "nope" : "none")
      });
      Dio dio = new Dio(
          new BaseOptions(
              baseUrl: "http://192.168.1.53:8000/bcdserver/")
      );

      setState(() {
        requestStatus = "waiting ...";
        waiting = true;
      });

      Response response = await dio.post("predict/", data: formData);

      setState(() {
        var encoder = new JsonEncoder.withIndent("    ");
        requestStatus = encoder.convert(response.data);
        //requestStatus = response.toString();
        waiting = false;
      });
      print("Response: " + response.toString());
    }
    catch(error){
      setState(() {
        requestStatus = error.toString();
        waiting = false;
      });
    }
  }

  Widget _buildText(RecordingStatus status) {
    var text = "";
    switch (_currentStatus) {
      case RecordingStatus.Initialized:
        {
          text = 'Start';
          break;
        }
      case RecordingStatus.Recording:
        {
          text = 'Pause';
          break;
        }
      case RecordingStatus.Paused:
        {
          text = 'Resume';
          break;
        }
      case RecordingStatus.Stopped:
        {
          text = 'Init';
          break;
        }
      default:
        break;
    }
    return Text(text, style: TextStyle(color: Colors.white));
  }

  void onPlayAudio(String path) async {
    if(audioPlayer != null) {
      await audioPlayer.stop();
      await audioPlayer.dispose();
      audioPlayer = null;
    }

    print("QQQ_play: " + path);
    audioPlayer = AudioPlayer();
    await audioPlayer.play(path, isLocal: true);
  }
}
