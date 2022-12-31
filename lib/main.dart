import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DataModel {
  String? msg;
  String? type;
  String? user;
  String? photo;

  DataModel({this.msg, this.type, this.user, this.photo});

  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      msg: json['msg'],
      type: json['type'],
      user: json['user'],
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['msg'] = this.msg;
    data['type'] = this.type;
    data['user'] = this.user;
    data['photo'] = this.photo;
    return data;
  }
}

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
late AndroidNotificationChannel channel;
bool isFlutterLocalNotificationsInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupFlutterNotifications();

  int id = Random().nextInt(950) + 1;
  String userId = id.toString();

  runApp(MyApp(userId: userId));
}

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  if (Platform.isAndroid) {
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
      'This channel is used for important notifications.', // description
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  const AndroidInitializationSettings initAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings intIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true);

  const InitializationSettings initSetting =
  InitializationSettings(android: initAndroid, iOS: intIOS);
  await flutterLocalNotificationsPlugin.initialize(initSetting);

  isFlutterLocalNotificationsInitialized = true;
}

class MyApp extends StatelessWidget {
  String userId;
  MyApp({super.key, this.userId = ''});

  @override
  Widget build(BuildContext context) {
    const title = 'Chat Room';
    return MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
        userId: userId,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.userId});

  final String title;
  final String userId;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  late final WebSocketChannel _channel;
  late StreamController<dynamic> streamController;
  List<DataModel> messageList = [];

  @override
  void initState() {
    String url = 'ws://127.0.0.1:3000';
    if (Platform.isAndroid) {
      url = 'ws://10.0.2.2:3000';
    }

    //Setup websocket to StreamController flutter
    _channel = WebSocketChannel.connect(Uri.parse(url));
    streamController = StreamController.broadcast();
    streamController.addStream(_channel.stream);

    print("Creating a StreamController and listen event...");
    streamController.stream.listen((data) {
      print("DataReceived1: " + data);
      final res = json.decode(data);
      final dataFull = DataModel.fromJson(res);
      _showNotification(dataFull);
      setState(() {
        messageList.add(dataFull);
      });
    }, onDone: () {
      print("Task Done1");
    }, onError: (error) {
      print("Some Error1");
    });
    super.initState();
  }

  Future<void> _showNotification(DataModel data) async {
    const AndroidNotificationDetails androidDetail = AndroidNotificationDetails(
        'test', 'แจ้งเตือนทั่วไป',
        importance: Importance.max, priority: Priority.high, ticker: 'ticker');

    const DarwinNotificationDetails iosDetail = DarwinNotificationDetails();

    const NotificationDetails platformChannel =
    NotificationDetails(android: androidDetail, iOS: iosDetail);

    await flutterLocalNotificationsPlugin.show(
        0, 'userID:${data.user}', data.msg, platformChannel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: getMessageList(),
            ),
            const SizedBox(height: 120)
          ],
        ),
      ),
      bottomSheet: chatBox(),
    );
  }

  Widget chatBox() {
    return Container(
      color: Colors.white70,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Send a message'),
            ),
          ),
          FloatingActionButton(
            onPressed: _sendMessage,
            tooltip: 'Send message',
            child: const Icon(Icons.send),
          )
        ],
      ),
    );
  }

  ListView getMessageList() {
    List<Widget> listWidget = [];

    for (var i = 0; i < messageList.length; i++) {
      final data = messageList[i];

      final userId = widget.userId;
      final isFriend = data.user != userId.toString();
      final photo = data.photo ?? '';

      //Logic msg friend
      bool hidePhoto = false;
      if (i > 0) {
        int idx = i - 1;
        if (data.user == messageList[idx].user) {
          hidePhoto = true;
        }
      }

      final itemChat = ListTile(
        dense: true,
        minVerticalPadding: 0,
        contentPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
        title: Row(
          mainAxisAlignment:
          isFriend ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            isFriend
                ? hidePhoto
                ? const SizedBox(width: 50)
                : Container(
              margin: const EdgeInsets.only(right: 10),
              child: CircleAvatar(
                backgroundImage: NetworkImage(photo),
              ),
            )
                : Container(),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 20.0),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.teal[50]),
                child: Text(
                  data.msg!,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      );

      // add chat to list
      listWidget.add(itemChat);
    }

    return ListView(children: listWidget);
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      String message = _controller.text;

      final userId = widget.userId.toString();

      DataModel data = DataModel();
      data.type = 'user';
      data.user = userId;
      data.photo = 'https://picsum.photos/id/$userId/200/200';
      data.msg = message;
      String body = json.encode(data);

      _channel.sink.add(body);
      setState(() {
        messageList.add(data);
      });
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    streamController.sink.close();
    super.dispose();
  }
}