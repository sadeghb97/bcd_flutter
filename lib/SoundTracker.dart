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

class SoundTracker {
  LocalFileSystem localFileSystem;
  FlutterAudioRecorder audioRecorder;
  Recording currentRecording;
  String lastRecordedPath;
  int startTime;
  int endTime;
  bool fired = false;

  BuildContext context;
  Timer timer;
  Function serverResponseRunnable;
  Function updateUiRunnable;

  SoundTracker(this.localFileSystem);

  setContext(BuildContext context){
    this.context = context;
  }

  init() async {
    try {
      if (await FlutterAudioRecorder.hasPermissions) {
        String customPath = '/flutter_audio_recorder_';
        io.Directory appDocDirectory;
        if (io.Platform.isIOS) {
          appDocDirectory = await getApplicationDocumentsDirectory();
        } else {
          appDocDirectory = await getExternalStorageDirectory();
        }

        customPath = appDocDirectory.path +
            customPath +
            DateTime.now().millisecondsSinceEpoch.toString();

        this.audioRecorder =
            FlutterAudioRecorder(customPath, audioFormat: AudioFormat.WAV, sampleRate: 44100);

        await this.audioRecorder.initialized;
        this.currentRecording = await this.audioRecorder.current(channel: 0);
        print("QQQInitDone");
      }
      else {
        Scaffold.of(context).showSnackBar(
            new SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  run() async {
    try {
      await init();
      startTime = DateTime.now().millisecondsSinceEpoch;
      await this.audioRecorder.start();
      fired = true;
      updateUiRunnable();

      this.currentRecording = await this.audioRecorder.current(channel: 0);
      print("QQQTimerRun");

      const tick = const Duration(milliseconds: 10000);

      this.timer = new Timer(tick, () async {
        print("QQQT.......................");

        endTime = DateTime.now().millisecondsSinceEpoch;
        var result = await this.audioRecorder.stop();
        print("QQQResultPath: " + result.path);
        File file = this.localFileSystem.file(result.path);
        print("QQQStop recording: ${result.path}");
        print("QQQStop recording: ${result.duration}");
        print("QQQ File length: ${await file.length()}");

        this.currentRecording = result;
        this.lastRecordedPath = result.path;
        print("QQQTickkkkkkkkkkkkkkkkkk");

        this.audioRecorder = null;
        this.currentRecording = null;
        print("QQQTickTwoooooooooooooooooo");

        requestServer(lastRecordedPath, startTime, endTime);
        run();
      });
    } catch (e) {
      print("QQQOccured!");
      print("QQQffffffffffffff");
      print("QQQERRRR: " + e.toString());
      print("QQQEr: " + e);
    }
  }

  stop() async {
    if(this.timer != null) timer.cancel();
    await this.audioRecorder.stop();
    fired = false;
    lastRecordedPath = null;
    currentRecording = null;
    updateUiRunnable();
    print("QQQStoppppppppppppped");
  }

  requestServer(String path, int startTime, int endTime) async {
    try {
      FormData formData = FormData.fromMap({
        "name": "Sadegh",
        "start_time": startTime,
        "end_time": endTime,
        "sound": await MultipartFile.fromFile(
          //"/storage/emulated/0/nope3.wav",
            path,
            filename: "newsignal.wav"
        ),
      });
      Dio dio = new Dio(
          new BaseOptions(
              baseUrl: "http://192.168.1.53:8000/bcdserver/")
      );

      Response response = await dio.post("predict/", data: formData);

      var encoder = new JsonEncoder.withIndent("    ");
      String requestStatus = encoder.convert(response.data);
      serverResponseRunnable(requestStatus);
      print("QQQResponse: " + response.toString());
    }
    catch(error){
      serverResponseRunnable(error.toString());
      print("QQQError: " + error.toString());
    }
  }
}