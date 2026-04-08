import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late AudioPlayer _player;
  final List<UriAudioSource> _playlist = [
    AudioSource.uri(Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/zero.mp3"),),
    AudioSource.uri(Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/one.mp3"),),
    AudioSource.uri(Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/two.mp3"),),
    //AudioSource.uri(Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/three.mp3"),),
  ];

  final List<UriAudioSource> _playlist1 = [
    AudioSource.uri(Uri.parse("https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/001001.mp3"),),
    AudioSource.uri(Uri.parse("https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/001002.mp3"),),
    AudioSource.uri(Uri.parse("https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/001003.mp3"),),
    AudioSource.uri(Uri.parse("https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/001004.mp3"),),
  ];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    //try {
    //await _player.setAudioSources(_playlist1, initialIndex: 0, initialPosition: Duration.zero, preload: true);
    //} catch (e) {
    //print("Error loading playlist: $e");
    //}

    _player.currentIndexStream.listen((index) {
      print('track $index');
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Center(
                child: TextButton(
                  onPressed: () {
                    _player.seek(Duration.zero, index: 0);
                    _player.play();
                  },
                  child: Text('Play'),
                ),
              ),
              TextButton(
                onPressed: () {
                  _player.stop();
                },
                child: Text('Stop'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.label),
            onPressed: () async {

              await _player.stop();
              await _player.setAudioSources(_playlist, initialIndex: 0, initialPosition: Duration.zero, preload: true);
              //_player.load();
              _player.play();
              /*
              await _playlist.insert(0, AudioSource.uri(
                Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/seven.mp3"),
              ));
              await _playlist.insert(2, AudioSource.uri(
                Uri.parse("https://oneworldofenglish.com/wp-content/uploads/2019/11/eight.mp3"),));
              */
              //print(_player.currentIndex);
              //_playlist.removeRange(0, 2);
              //print(_player.currentIndex);
            },
          ),
        )
    );
  }
}
