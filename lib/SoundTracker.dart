import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'Constants.dart';

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

  String lastResponseMessage;
  List signalsResult;
  List modelsResult = new List(DETECTOR_MODELS.length);

  SoundTracker(this.localFileSystem);

  setContext(BuildContext context){
    this.context = context;
  }

  init() async {
    print("QQQKhdddddddddddddd");
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
      const tick = const Duration(milliseconds: 10000);

      this.timer = new Timer(tick, () async {
        endTime = DateTime.now().millisecondsSinceEpoch;
        var result = await this.audioRecorder.stop();
        File file = this.localFileSystem.file(result.path);
        this.currentRecording = result;
        this.lastRecordedPath = result.path;

        this.audioRecorder = null;
        this.currentRecording = null;

        requestServer(lastRecordedPath, startTime, endTime);
        run();
      });
    } catch (e) {
      print("QQQERRRR: " + e.toString());
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
      lastResponseMessage = encoder.convert(response.data);
      print("QQQResponse: " + response.toString());

      modelsResult = new List();
      if(response.data.containsKey("result")){
        signalsResult = new List();
        response.data['result']['signals'].forEach((v) {
          signalsResult.add(v['cry']);
        });

        List svcPreds = new List();
        response.data['result']['svc']['signals'].forEach((v) {
          svcPreds.add(v['confidence']);
        });
        modelsResult.add(svcPreds);

        List svcV1Preds = new List();
        response.data['result']['svc_v1']['signals'].forEach((v) {
          svcV1Preds.add(v['confidence']);
        });
        modelsResult.add(svcV1Preds);

        List linSvcPreds = new List();
        response.data['result']['linsvc']['signals'].forEach((v) {
          linSvcPreds.add(v['confidence']);
        });
        modelsResult.add(linSvcPreds);

        List mlpPreds = new List();
        response.data['result']['mlp']['signals'].forEach((v) {
          mlpPreds.add(v['confidence']);
        });
        modelsResult.add(mlpPreds);
      }
      else {
        //Error
      }

      serverResponseRunnable(lastResponseMessage);
    }
    catch(error){
      signalsResult = null;
      modelsResult = new List(DETECTOR_MODELS.length);
      lastResponseMessage = error.toString();
      serverResponseRunnable(lastResponseMessage);
      print("QQQError: " + error.toString());
    }
  }
}