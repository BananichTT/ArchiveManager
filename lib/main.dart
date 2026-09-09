import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'features/home/screens/home_screen.dart';
import 'features/downloads/screens/downloads_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArchiveManagerApp());
}

class ArchiveManagerApp extends StatefulWidget {
  const ArchiveManagerApp({super.key});

  @override
  State<ArchiveManagerApp> createState() => _ArchiveManagerAppState();
}

class _ArchiveManagerAppState extends State<ArchiveManagerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initSharing();
  }

  void _initSharing() {
    // Listen to sharing images coming from outside the app while the app is in the memory
    ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _navigateToDownloads();
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // Get the images shared from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _navigateToDownloads();
      }
    });
  }

  void _navigateToDownloads() {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DownloadsScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Archive Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
