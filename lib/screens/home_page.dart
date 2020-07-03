import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:apod_app/api_class_data/aopd_api_class.dart';
import 'package:apod_app/common_var_and_func/common_functions.dart';
import 'package:apod_app/themes_data/dark_theme_provider.dart';
import "package:flutter/material.dart";
import 'package:apod_app/api_get_data/api_get_data.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';

ApodAPICallback _apodAPICallback = new ApodAPICallback();
const debug = true;

class _TaskInfo {
  final String name;
  final String link;

  String taskId;
  int progress = 0;
  DownloadTaskStatus status = DownloadTaskStatus.undefined;

  _TaskInfo({
    this.name,
    this.link,
  });
}

class HomePage extends StatefulWidget with WidgetsBindingObserver {
  final TargetPlatform platform;

  @override
  HomePage({
    this.platform,
  });

  @override
  State<HomePage> createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<_TaskInfo> _tasks;
  bool _permissionReady;
  String _localPath;
  ReceivePort _port = ReceivePort();

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen(
      (dynamic data) {
        if (debug) {
          print('UI Isolate Callback: $data');
        }
        String id = data[0];
        DownloadTaskStatus status = data[1];
        int progress = data[2];

        final task = _tasks?.firstWhere((task) => task.taskId == id);
        if (task != null) {
          setState(
            () {
              task.status = status;
              task.progress = progress;
            },
          );
        }
      },
    );
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    if (debug) {
      print(
          'Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
    }
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
  }

  void _requestDownload(_TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
        url: task.link,
        headers: {"auth": "test_for_sql_encoding"},
        savedDir: _localPath,
        showNotification: true,
        openFileFromNotification: true);
  }

  Future<bool> _checkPermission() async {
    if (widget.platform == TargetPlatform.android) {
      PermissionStatus permission = await Permission.storage.request();
      if (permission != PermissionStatus.granted) {
        Map<Permission, PermissionStatus> permissions =
            await [Permission.storage].request();
        if (permissions[Permission.storage] == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  _TaskInfo createTask(String name, String link) {
    _TaskInfo task = _TaskInfo(
      name: name,
      link: link,
    );

    return task;
  }

  Future<Null> _prepare() async {
    _permissionReady = await _checkPermission();

    _localPath =
        (await _findLocalPath()) + Platform.pathSeparator + 'ApodImages';

    final savedDir = Directory(_localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
  }

  Future<String> _findLocalPath() async {
    final directory = widget.platform == TargetPlatform.android
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // ignore: missing_return
  Widget _buildActionForTask(_TaskInfo task) {
    if (task.status == DownloadTaskStatus.undefined) {
      return OutlineButton(
        onPressed: () {
          _permissionReady
              ? _requestDownload(task)
              : Container(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Please grant accessing storage permission to continue -_-',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.blueGrey, fontSize: 18.0),
                          ),
                        ),
                        SizedBox(
                          height: 32.0,
                        ),
                        FlatButton(
                          onPressed: () {
                            _checkPermission().then((hasGranted) {
                              setState(() {
                                _permissionReady = hasGranted;
                              });
                            });
                          },
                          child: Text(
                            'Retry',
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0),
                          ),
                        )
                      ],
                    ),
                  ),
                );
        },
        textColor: Theme.of(context).textSelectionColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Octicons.cloud_download),
            SizedBox(
              width: 5,
            ),
            Text(
              "Download",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
  }

  DateTime pickedDate = DateTime.now();

  Future<Apod> _apodFunc() {
    return _apodAPICallback.getData(
      pickedDate.toString().substring(0, 10),
    );
  }

  Future<Apod> _apodData;

  @override
  void initState() {
    super.initState();
    _apodData = _apodFunc();
    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback);
    _permissionReady = false;

    _prepare();
  }

  Future<Null> _datePicker(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: pickedDate,
      firstDate: DateTime(2012, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != pickedDate)
      setState(
        () {
          _apodData = _apodFunc();
          pickedDate = picked;
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            onPressed: () {
              themeChange.darkTheme = !themeChange.darkTheme;
            },
            icon: themeChange.darkTheme
                ? Icon(Ionicons.ios_sunny)
                : Icon(Ionicons.ios_moon),
          ),
        ],
        title: Text(
          "Astronomy Picture Of the Day",
        ),
      ),
      body: ListView(
        children: <Widget>[
          SizedBox(
            height: 10,
          ),
          Container(
            alignment: Alignment.center,
            height: 50,
            child: InkWell(
              onTap: () => _datePicker(context),
              child: Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Octicons.calendar),
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      "$pickedDate".split(' ')[0],
                      style: TextStyle(fontSize: 18),
                    )
                  ],
                ),
              ),
            ),
          ),
          FutureBuilder(
            future: _apodData,
            builder: (BuildContext context, AsyncSnapshot<Apod> _apodSnap) {
              if (_apodSnap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Card(
                      elevation: 36,
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              "${_apodSnap.data.title}",
                              style: TextStyle(fontSize: 25),
                            ),
                          ),
                          getContainer(
                            _apodSnap.data,
                            context,
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          ButtonBar(
                            alignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              OutlineButton(
                                textColor: Theme.of(context).textSelectionColor,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Ionicons.md_share),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Text(
                                      "Share",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                onPressed: () {
                                  final RenderBox box =
                                      context.findRenderObject();
                                  Share.share(
                                      "${_apodSnap.data.title} ->  ${_apodSnap.data.hdurl}",
                                      subject: _apodSnap.data.title,
                                      sharePositionOrigin:
                                          box.localToGlobal(Offset.zero) &
                                              box.size);
                                },
                              ),
                              if (_apodSnap.data.mediaType == "image")
                                _buildActionForTask(
                                  createTask(_apodSnap.data.title,
                                      _apodSnap.data.hdurl),
                                ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              "${_apodSnap.data.explanation}",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }
}
