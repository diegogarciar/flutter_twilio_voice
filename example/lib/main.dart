import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_twilio_voice/flutter_twilio_voice.dart';
import 'package:flutter_twilio_voice_example/call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DialScreen());
  }
}

class DialScreen extends StatefulWidget {
  @override
  _DialScreenState createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> with WidgetsBindingObserver {
  TextEditingController _controller;
  String userId;

  registerUser() {
    print("voip- service init");
    // if (FlutterTwilioVoice.deviceToken != null) {
    //   print("device token changed");
    // }

    register();

    FlutterTwilioVoice.setOnDeviceTokenChanged((token) {
      print("voip-device token changed");
      register();
    });
  }

  register() async {
    print("voip-registtering with token ");
    print("voip-calling voice-accessToken");
    final function =
        FirebaseFunctions.instance.httpsCallable("voice-accessToken");

    final data = {
      "platform": Platform.isIOS ? "iOS" : "Android",
    };

    final result = await function.call(data);
    print("voip-result");
    print(result.data);
    String androidToken;
    if (Platform.isAndroid) {
      androidToken = await FirebaseMessaging.instance.getToken();
      print("androidToken is " + androidToken);
    }
    FlutterTwilioVoice.tokens(
        accessToken: result.data, deviceToken: androidToken);
  }

  var registered = false;
  waitForLogin() {
    final auth = FirebaseAuth.instance;
    auth.authStateChanges().listen((user) async {
      // print("authStateChanges $user");
      if (user == null) {
        print("user is anonomous");
        await auth.signInAnonymously();
      } else if (!registered) {
        registered = true;
        this.userId = user.uid;
        print("registering user ${user.uid}");
        registerUser();
        // FirebaseMessaging.instance.configure(
        //     onMessage: (Map<String, dynamic> message) {
        //   print("onMessage");
        //   print(message);
        //   return;
        // }, onLaunch: (Map<String, dynamic> message) {
        //   print("onLaunch");
        //   print(message);
        //   return;
        // }, onResume: (Map<String, dynamic> message) {
        //   print("onResume");
        //   print(message);
        //   return;
        // });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    waitForLogin();

    super.initState();
    waitForCall();
    WidgetsBinding.instance.addObserver(this);

    final partnerId = "alicesId";
    FlutterTwilioVoice.registerClient(partnerId, "Alice");
    _controller = TextEditingController(text: "");
  }

  checkActiveCall() async {
    final isOnCall = await FlutterTwilioVoice.isOnCall();
    print("checkActiveCall $isOnCall");
    if (isOnCall &&
        !hasPushedToCall &&
        FlutterTwilioVoice.callDirection == CallDirection.incoming) {
      print("user is on call");
      pushToCallScreen();
      hasPushedToCall = true;
    }
  }

  var hasPushedToCall = false;

  void waitForCall() {
    checkActiveCall();
    FlutterTwilioVoice.onCallStateChanged.listen((event) {
      print("voip-onCallStateChanged $event");

      switch (event) {
        case CallState.answer:
          //at this point android is still paused
          if (Platform.isIOS && state == null ||
              state == AppLifecycleState.resumed) {
            pushToCallScreen();
            hasPushedToCall = true;
          }
          break;
        case CallState.connected:
          if (Platform.isAndroid &&
              FlutterTwilioVoice.callDirection == CallDirection.incoming) {
            if (state != AppLifecycleState.resumed) {
              FlutterTwilioVoice.showBackgroundCallUI();
            } else if (state == null || state == AppLifecycleState.resumed) {
              pushToCallScreen();
              hasPushedToCall = true;
            }
          }
          break;
        case CallState.call_ended:
          hasPushedToCall = false;
          break;
        default:
          break;
      }
    });
  }

  AppLifecycleState state;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
    print("didChangeAppLifecycleState");
    if (state == AppLifecycleState.resumed) {
      checkActiveCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(
                      labelText: 'Client Identifier or Phone Number'),
                ),
                SizedBox(
                  height: 10,
                ),
                RaisedButton(
                  child: Text("Make Call"),
                  onPressed: () async {
                    if (!await FlutterTwilioVoice.hasMicAccess()) {
                      print("request mic access");
                      FlutterTwilioVoice.requestMicAccess();
                      return;
                    }
                    FlutterTwilioVoice.makeCall(
                        to: _controller.text, from: userId);
                    pushToCallScreen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void pushToCallScreen() {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        fullscreenDialog: true, builder: (context) => CallScreen()));
  }
}
