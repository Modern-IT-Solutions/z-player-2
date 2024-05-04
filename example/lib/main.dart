import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_cache_manager/media_cache_manager.dart';
import 'package:zplayer/zplayer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ZPlayer.ensureInitialized();
  MediaCacheManager.instance.init(
    encryptionPassword: "PASSWORD",
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TestZPlayer(),
    );
  }
}

class TestZPlayer extends StatefulWidget {
  const TestZPlayer({
    super.key,
  });

  @override
  State<TestZPlayer> createState() => _TestZPlayerState();
}

class _TestZPlayerState extends State<TestZPlayer> {
  final Map<String, String> _videos = {
    "bNyUyrR0PHo":"aljazeera",
    "KuXjwB4LzSA":"But what is a convolution? ",
    "Lakz2MoHy6o":"Convolutional Neural Network",
    "h7apO7q16V0":"Fast Fourier Transform",
    "spUNpyF58BY":"Discrete Fourier Transform",
    "jNQXAC9IVRw":"Me at the zoo",
  };

  late String _selectedVideoId;

  // at init state select random video
  @override
  void initState() {
    super.initState();
    _selectedVideoId =
        Random().nextBool() ? _videos.keys.first : _videos.keys.last;
    select(_selectedVideoId);
  }

  Set<ZStream> streams = {};

  Future<void> select(String id) async {
    _selectedVideoId = id;
    streams.clear();
    setState(() {
      
    });
    try {
      streams = await Youtube.instance.streams(_selectedVideoId);
      streams = {streams.where((element) => element.type == ZStreamType.muxed).first};
    } catch (e) {
      print('streams exp');
      print(e);
    }
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          if (streams.isNotEmpty)
          DownloadMediaBuilder(
            url: streams.first.src,
            onLoading: (snapshot) {
              return Text('loading ${snapshot.progress}');
            },
            onSuccess: (snapshot) {
              return Text('success ${snapshot.filePath}');
            },
            onDecrypting: (snapshot) {
              return Text('decrypting ${snapshot.progress}');
            },
            onEncrypting: (snapshot) {
              return Text('encrypting ${snapshot.progress}');
            },
          ),
          if (streams.isNotEmpty)
            ZPlayer(
              key: ValueKey(_selectedVideoId),
              streams:
               streams,
              title: Text(_videos[_selectedVideoId]!),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          for (var id in _videos.keys)
            ListTile(
              selected: _selectedVideoId == id,
              title: Text(_videos[id]!),
              onTap: () {
                select(id);
              },
            ),
        ],
      ),
    );
  }
}
