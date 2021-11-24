import 'dart:math';

import 'package:chat/chat/chat.dart';
import 'package:chat/chat/chat_vm.dart';
import 'package:chat/messages/message_vm.dart';
import 'package:chat/messages/messages.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart';

void main() {
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => MessagesVM())],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MessagesPage(),
      onGenerateRoute: Router.onGenerrateRoute,
    );
  }
}

extension BuildConttextEx on BuildContext {
  T routeArgs<T>() => ModalRoute.of(this)?.settings.arguments as T;
}

extension RouteSettingsEx on RouteSettings {
  T? routeArgs<T>() => arguments as T?;
}

class Router {
  static Route onGenerrateRoute(RouteSettings routeSettings) {
    bool fullscreenDialog = false;
    late WidgetBuilder widgetBuilder;

    switch (routeSettings.name) {
      case "/":
        widgetBuilder = (_) => const MessagesPage();
        break;
      case "/chat":
        widgetBuilder = (_) => ChangeNotifierProvider(
            create: (_) => ChatVM(routeSettings.routeArgs()),
            child: const ChatPage());
        break;
      default:
        widgetBuilder = (_) => Container();
    }

    return MaterialPageRoute(
        builder: widgetBuilder,
        settings: routeSettings,
        fullscreenDialog: fullscreenDialog);
  }
}

class SocketClient {
  static int id = Random().nextInt(9999);
  static Socket? _socket;
  static Socket get instance {
    _socket ??= io("https://socketio-chat-h9jt.herokuapp.com/",
            OptionBuilder().setTransports(['websocket']).build())
        .connect();

    _socket!.onConnect((_) {
      _socket!.emit('add user', "User$id");
    });

    return _socket!;
  }
}







import 'package:chat/messages/message_vm.dart';
import 'package:chat/model/user.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);
  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  @override
  Widget build(BuildContext context) {
    List<Message> messages = context.watch<MessagesVM>().messages;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaages'),
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.home))],
      ),
      body: ListView.separated(
          separatorBuilder: (c, i) {
            return const Divider(
              height: 1,
            );
          },
          itemCount: messages.length,
          itemBuilder: (c, i) {
            Message message = messages[i];
            return ListTile(
              onTap: () {
                Navigator.pushNamed(context, "/chat",
                    arguments: message.username);
              },
              leading: ClipOval(child: Image.network(message.image)),
              title: Text(message.username),
              subtitle: message.isTyping
                  ? Text("typing")
                  : message.message != null
                      ? Text(
                          message.message!,
                          maxLines: 2,
                        )
                      : null,
            );
          }),
    );
  }
}



import 'package:chat/main.dart';
import 'package:chat/model/user.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:collection/collection.dart';

class MessagesVM extends ChangeNotifier {
  Socket socket = SocketClient.instance;
  final List<Message> _messages = [];
  List<Message> get messages => _messages;

  MessagesVM() {
    socket.on('user joined', (data) {
      _messages.add(Message(
          id: data["numUsers"], username: data["username"], message: ""));
      notifyListeners();
    });

    socket.on('typing', (data) {
      _messages
          .firstWhereOrNull((element) => element.username == data["username"])
          ?.isTyping = true;
      notifyListeners();
    });

    socket.on('stop typing', (data) {
      _messages
          .firstWhereOrNull((element) => element.username == data["username"])
          ?.isTyping = false;
      notifyListeners();
    });

    socket.on('new message', (data) {
      _messages
          .firstWhereOrNull((element) => element.username == data["username"])
          ?.message = data["message"];
      notifyListeners();
    });
  }
}


import 'package:chat/chat/chat_model.dart';
import 'package:chat/main.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';

class ChatVM extends ChangeNotifier {
  Socket socket = SocketClient.instance;
  late String _username;
  String get username => _username;
  ChatVM(String username) {
    _username = username;
    socket.on('new message', (data) {
      if (data["username"] == username) {
        _chat.add(Chat(message: data["message"], user: username));
        notifyListeners();
      }
    });
  }

  final List<Chat> _chat = [];
  List<Chat> get chat => _chat;
  bool _typing = false;
  String? _message;
  String? get message => _message;
  void setMessage(String? msg) {
    _message = msg;
    if (!_typing) {
      _typing = true;
      socket.emit('typing');
      Future.delayed(const Duration(milliseconds: 400)).then((v) {
        if (_typing) {
          _typing = false;
          socket.emit('stop typing');
        }
      });
    }
    notifyListeners();
  }

  void sendMessage() {
    socket.emit('new message', message);
    _chat.add(Chat(message: message!, user: "Emin"));
    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }
}


class Chat {
  String user;
  String message;
  Chat({
    required this.user,
    required this.message,
  });
}


import 'package:chat/chat/chat_model.dart';
import 'package:chat/chat/chat_vm.dart';
import 'package:chat/messages/message_vm.dart';
import 'package:chat/model/user.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  Widget build(BuildContext context) {
    Message message = context.watch<MessagesVM>().messages.firstWhere(
        (element) => element.username == context.read<ChatVM>().username);
    List<Chat> chats = context.watch<ChatVM>().chat;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
                height: 56,
                padding: const EdgeInsets.all(8.0),
                child: ClipOval(child: Image.network(message.image))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.username),
                Visibility(
                    visible: message.isTyping,
                    child: const Text(
                      "typing",
                      style: TextStyle(fontSize: 12),
                    ))
              ],
            ),
          ],
        ),
      ),
      body: ListView.builder(
          padding: const EdgeInsets.only(bottom: 56),
          itemCount: chats.length,
          reverse: true,
          itemBuilder: (c, i) {
            Chat item = chats.reversed.toList()[i];
            return generateChat(item);
          }),
      bottomSheet: Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: TextField(
                controller: context.watch<ChatVM>().message != null
                    ? null
                    : TextEditingController(),
                expands: false,
                maxLines: null,
                onChanged: context.read<ChatVM>().setMessage,
                decoration: const InputDecoration(
                    hintText: "Aaa...", contentPadding: EdgeInsets.all(8)),
              ),
            ),
            IconButton(
                onPressed: context.watch<ChatVM>().message == null
                    ? null
                    : context.read<ChatVM>().sendMessage,
                icon: const Icon(
                  Icons.send,
                  color: Colors.black,
                ))
          ],
        ),
      ),
    );
  }

  Widget generateChat(Chat item) {
    if (item.user == "Emin") {
      return Container(
          padding:
              const EdgeInsets.only(left: 64, right: 16, top: 4, bottom: 4),
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue.shade200,
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                item.message,
              ),
            ),
          ));
    } else {
      return Container(
          padding:
              const EdgeInsets.only(left: 16, right: 64, top: 4, bottom: 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                item.message,
              ),
            ),
          ));
    }
  }
}


import 'dart:math';

class Message {
  int id;
  String username;
  String image;
  String? message;
  bool isTyping;
  Message(
      {required this.id,
      required this.username,
      this.message,
      this.isTyping = false})
      : image =
            "https://randomuser.me/api/portraits/men/${Random().nextInt(99)}.jpg";
}
