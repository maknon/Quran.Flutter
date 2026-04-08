import 'package:haq/painter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'db.dart' as db;
import 'services.dart';

import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

typedef MyBuilder = void Function(BuildContext context, void Function(int page) methodFromChild);

Future<void> main() async {

  //JustAudioMediaKit.prefetchPlaylist = true;
  JustAudioMediaKit.ensureInitialized(linux: true, windows: true);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'القرآن الكريم',
      locale: const Locale('ar'),
      scrollBehavior: const ScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      }, scrollbars: false),
      home: FutureBuilder<int>(
        future: getPage(),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            // Future not done, return a temporary loading widget
            return const CircularProgressIndicator();
          }
          // Future is done
          return Directionality(
            textDirection: TextDirection.rtl,
            child: QuranApp(
              setting: Setting(
                  false, db.qiraatPath.elementAt(0), snapshot.data ?? 0, false, -1),
            ),
          );
        },
      ),
    ),
  );
}

Future<int> getPage() async {
  WidgetsFlutterBinding.ensureInitialized(); // Needed if SharedPreferences is needed before runApp()
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final int page = prefs.getInt('page') ?? 0;
  return page;
}

class Setting {
  bool nightTheme;
  String qiraat;
  int page;
  bool qiraatChanged;
  int suraChanged;

  Setting(this.nightTheme, this.qiraat, this.page, this.qiraatChanged, this.suraChanged);
}

class QuranApp extends StatefulWidget {
  final Setting setting;

  const QuranApp({super.key, required this.setting});

  @override
  State<StatefulWidget> createState() {
    return QuranAppState();
  }
}

bool previousButtonEvent = false;
bool repetitionEvent = false;
enum Repetition {aya, page}
Repetition repetitionType = Repetition.aya;

class QuranAppState extends State<QuranApp> {
  QuranAppState();

  late final TextEditingController _pageTextController;
  late final PageController _pageController;
  late final ConcatenatingAudioSource _playlist;
  late final AudioPlayer _player;
  final ValueNotifier<bool> appBar = ValueNotifier<bool>(true);
  final ValueNotifier<bool> bottomAppBar = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer(); // useLazyPreparation: false
    _pageTextController = TextEditingController();
    _pageController = PageController(
        initialPage: widget.setting.page,
        keepPage: false
    );

    // empty list [] is not working in web. bug. TODO recheck again with new releases
    _playlist = kIsWeb
        ? ConcatenatingAudioSource(children: [AudioSource.uri(Uri.parse(''))])
        : ConcatenatingAudioSource(children: []);
  }

  @override
  void dispose() {
    _pageTextController.dispose();
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: AppBar().preferredSize,
        child: ValueListenableBuilder<bool>(
          valueListenable: appBar,
          builder: (context, value, child) {
            return value ? AppBar(
              centerTitle: true,
              //forceMaterialTransparency: true,
              backgroundColor: widget.setting.nightTheme
                  ? const Color.fromRGBO(0, 0, 0, 0.85)
                  : const Color.fromRGBO(0, 0, 0, 0.40),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if(kIsWeb && defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS) // ipad is considered macOS !
                    IconButton(
                        color: const Color.fromRGBO(255, 255, 255, 0.90),
                        onPressed: () =>
                        {
                          launch('https://play.google.com/store/apps/details?id=com.maknoon.haq', isNewTab: true)
                        }, icon: const Icon(Icons.android)),
                  if(kIsWeb && defaultTargetPlatform != TargetPlatform.android)
                    IconButton(
                        color: const Color.fromRGBO(255, 255, 255, 0.90),
                        onPressed: () =>
                        {
                          launch('https://apps.apple.com/us/app/the-noble-quran-%D8%A7%D9%84%D9%82%D8%B1%D8%A2%D9%86-%D8%A7%D9%84%D9%83%D8%B1%D9%8A%D9%85/id6714458468?platform=iphone', isNewTab: true)
                        }, icon: const Icon(Icons.apple)),
                  if(kIsWeb)
                    IconButton(
                        color: const Color.fromRGBO(255, 255, 255, 0.90),
                        onPressed: () =>
                        {
                          launch('https://maknoon.com/download/quran/quran_${widget.setting.qiraat}_m.pdf', isNewTab: true)
                        }, icon: const Icon(Icons.picture_as_pdf_outlined)),
                  IconButton(
                      color: const Color.fromRGBO(255, 255, 255, 0.90),
                      onPressed: () =>
                      {
                        setState(() {
                          widget.setting.nightTheme =
                          !widget.setting.nightTheme;
                        })
                      }, icon: const Icon(Icons.nightlight)),
                  PopupMenuButton(
                      tooltip: 'القراءات',
                      iconColor: const Color.fromRGBO(255, 255, 255, 0.90),
                      icon: const Icon(Icons.menu_book),
                      itemBuilder: (context) => db.qiraat.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
                      onSelected: (value) {
                        setState(() async {
                          final int v = db.qiraat.indexOf(value);
                          widget.setting.qiraat = db.qiraatPath.elementAt(v);
                          widget.setting.qiraatChanged = true;
                          locationIndex.value = -1;
                          if (_player.playing) {
                            await _player.stop();
                            _player.seek(Duration.zero);
                          }
                          if (v == 0) {
                            bottomAppBar.value = appBar.value;
                          }
                          else {
                            bottomAppBar.value = false;
                          }
                        });
                      }
                  ),
                  IconButton(
                      color: const Color.fromRGBO(255, 255, 255, 0.90),
                      onPressed: () =>
                      {
                        showDialog(
                            context: context,
                            builder: (context) {
                              return Directionality(
                                textDirection: TextDirection.rtl,
                                child: AlertDialog(
                                  contentPadding: const EdgeInsets.fromLTRB(50, 16, 50, 24),
                                  content: TextField(
                                    textAlign: TextAlign.center,
                                    showCursor: false,
                                    autofocus: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      NumericalRangeFormatter(min: 1, max: 604),
                                    ],
                                    keyboardType: TextInputType.number,
                                    controller: _pageTextController,
                                    decoration: const InputDecoration(hintText: 'الصفحة'),
                                    onSubmitted: (value) {
                                      goTo();
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        goTo();
                                      },
                                      child: const Text('اذهب'),
                                    ),
                                  ],
                                ),
                              );
                            }
                        )
                      }, icon: const Icon(Icons.pin_outlined)),
                  PopupMenuButton(
                      tooltip: 'السورة',
                      iconColor: const Color.fromRGBO(255, 255, 255, 0.90),
                      icon: const Icon(Icons.list),
                      itemBuilder: (context) => db.sura.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
                      onSelected: (value) {
                        final int v = db.sura.indexOf(value);
                        widget.setting.page = db.suraPage.elementAt(v) - 1;
                        widget.setting.suraChanged = v;
                        jumpTo.call(widget.setting.page); // << this will execute the methodFromChild
                      }
                  ),
                  PopupMenuButton(
                      tooltip: 'الجزء',
                      iconColor: const Color.fromRGBO(255, 255, 255, 0.90),
                      icon: const Icon(Icons.layers),
                      itemBuilder: (context) => db.juz.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
                      onSelected: (value) {
                        int v = db.juz.indexOf(value);
                        widget.setting.page = db.juzPage.elementAt(v) - 1;
                        jumpTo.call(widget.setting.page); // << this will execute the methodFromChild
                      }
                  ),
                  if(kIsWeb)
                    IconButton(
                        color: const Color.fromRGBO(255, 255, 255, 0.90),
                        onPressed: () =>
                        {
                          launch('https://www.maknoon.com/community/forums/16', isNewTab: true)
                        }, icon: const Icon(Icons.home)),
                ],
              ),
            ) : const SizedBox.shrink();
          },
        ),
      ),
      backgroundColor: widget.setting.nightTheme
          ? Colors.black
          : const Color.fromRGBO(255, 255, 242, 1.0),
      body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            appBar.value = !appBar.value;
            if (widget.setting.qiraat == db.qiraatPath.elementAt(0)) {
              bottomAppBar.value = appBar.value;
            }
            else {
              bottomAppBar.value = false;
            }
          },
          // LayoutBuilder is needed to get proper width and remove extra padding https://github.com/flutter/flutter/issues/159329
          child: LayoutBuilder(builder: (context, constraints) {
            return QuranPageView(
              _playlist,
              _pageController,
              _player,
              constraints.maxWidth,
              setting: widget.setting,
              builder: (BuildContext context, void Function(int page) methodFromChild) {
                jumpTo = methodFromChild;
              },
            );
          })
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: bottomAppBar,
        builder: (context, value, child) {
          return value ? BottomAppBar(
            padding: EdgeInsets.zero,
            //double? h = Scaffold.of(context).appBarMaxHeight; // working also https://stackoverflow.com/questions/50075945/how-to-get-appbar-height-in-flutter
            //height = AppBar().preferredSize.height; // working also
            height: kToolbarHeight,
            color: widget.setting.nightTheme
                ? const Color.fromRGBO(0, 0, 0, 0.85)
                : const Color.fromRGBO(0, 0, 0, 0.40),
            child: IconTheme(
              data: IconThemeData(color: Theme
                  .of(context)
                  .colorScheme
                  .onPrimary),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ValueListenableBuilder<int>(
                    valueListenable: repetitionCount,
                    builder: (context, value, child) {
                      return GestureDetector(
                        /*
                            onLongPress: () {
                              showDialog(
                                  context: context,
                                  builder: (context) =>
                                      StatefulBuilder(
                                          builder: (context, setStateLocal) {
                                            return Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: SimpleDialog(
                                                children: <Widget>[
                                                  RadioListTile<Repetition>(
                                                      value: Repetition.page,
                                                      title: const Text('تكرار الصفحة'),
                                                      groupValue: repetitionType,
                                                      onChanged: (v) {
                                                        setState(() {
                                                          repetitionEvent = true;
                                                          repetitionType = v!;
                                                        });
                                                        Navigator.pop(context);
                                                      }),
                                                  RadioListTile<Repetition>(
                                                    value: Repetition.aya,
                                                    title: const Text('تكرار الآية'),
                                                    groupValue: repetitionType,
                                                    onChanged: (v) {
                                                      setState(() {
                                                        repetitionEvent = true;
                                                        repetitionType = v!;
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                      )
                              );
                            },
                           */
                          child: IconButton(
                            icon: Badge(
                                isLabelVisible: true,
                                label: Text(repetitionCount.value.toString()),
                                //alignment: AlignmentDirectional.bottomStart,
                                //offset: const Offset(12, 12),
                                child: const Icon(Icons.repeat)
                            ),
                            onPressed: () async {
                              if (repetitionCount.value == maxRepetition) {
                                repetitionCount.value = 1;
                              } else {
                                repetitionCount.value++;
                              }
                              if (repetitionType == Repetition.aya) {
                                await updatePlayList(_playlist);
                              }
                            },
                          )
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      if (locationIndex.value == 0) {
                        // clicking previous while first aya in page is reached
                        previousButtonEvent = true;
                        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                      }
                      else {
                        if (locationIndex.value != -1) {
                          if (repetitionCount.value != 1 && repetitionType == Repetition.aya) {
                            _player.seek(Duration.zero, index: track - (track % repetitionCount.value) - repetitionCount.value);
                          } else {
                            _player.seekToPrevious();
                          }
                        }
                      }
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isPlaying,
                    builder: (context, value, child) {
                      return IconButton(
                        icon: Icon(value ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (_player.playing) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () async {
                      await _player.stop();
                      locationIndex.value = -1;
                      if (repetitionCount.value != 1 && repetitionType == Repetition.aya) {
                        await _player.seek(Duration.zero, index: 0); // TODO we need to reset all track and index since track is not triggered while stopped and this causes errors
                        repetitionCount.value = 1;
                        await updatePlayList(_playlist);
                      }
                      else {
                        _player.seek(Duration.zero);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      if (locationIndex.value == (sura.length - 1)) {
                        // end of page is reached
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                      }
                      else {
                        if (locationIndex.value != -1) {
                          if (repetitionCount.value != 1 && repetitionType == Repetition.aya) {
                            _player.seek(Duration.zero, index: track - (track % repetitionCount.value) + repetitionCount.value);
                          } else {
                            _player.seekToNext();
                          }
                        }
                      }
                    },
                  ),
                  PopupMenuButton(
                      tooltip: 'القارئ',
                      icon: const Icon(Icons.record_voice_over),
                      itemBuilder: (context) => db.sheekh.map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
                      onSelected: (value) async {
                        sheekhIndex = db.sheekh.indexOf(value);
                        await prepareList(_player, _playlist);
                        await _player.seek(Duration.zero);
                        _player.play();
                      }
                  ),
                ],
              ),
            ),
          ) : const SizedBox.shrink();
        },
      ),
    );
  }

  late void Function(int page) jumpTo;

  void goTo() {
    try {
      final String num = _pageTextController.text;
      if (num.isNotEmpty) {
        int page = int.parse(_pageTextController.text);

        if (page > 604 || page < 1) {
          throw const FormatException();
        }

        widget.setting.page = page - 1;
        jumpTo.call(widget.setting.page);
      }
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }

    Navigator.pop(context);
    _pageTextController.text = '';
  }
}

Future<void> launch(String url, {bool isNewTab = true}) async {
  await launchUrl(
    Uri.parse(url),
    webOnlyWindowName: isNewTab ? '_blank' : '_self',
  );
}

class QuranPageView extends StatefulWidget {
  final Setting setting;
  final MyBuilder builder;
  final AudioPlayer _player;
  final PageController _pageController;
  final double displayWidth;
  final ConcatenatingAudioSource _playlist;

  const QuranPageView(this._playlist, this._pageController, this._player, this.displayWidth, {
    super.key, required this.setting, required this.builder
  });

  @override
  State<StatefulWidget> createState() {
    return QuranPageViewState();
  }
}

int sheekhIndex = 0;
final List<int> sura = [];
final List<int> aya = [];
final List<Path> locations = [];
Future<void> prepareList(AudioPlayer player, ConcatenatingAudioSource playlist) async {
  if (kDebugMode) {
    print('prepareList');
  }

  final List<UriAudioSource> mediaList = [];
  final List<UriAudioSource> mediaRepetitionList = [];
  playListSrc.clear();
  for (int i = 0; i < sura.length; i++) {
    String filename = '${sura[i].toString().padLeft(3, '0')}${aya[i].toString().padLeft(3, '0')}.mp3';

    if (aya[i] == 0) {
      // Most sheekh do not have basmalah in every sura or merged with esteaatha
      // Mohammad_al_Tablaway_64kbps / Muhammad_Ayyoub_64kbps only ones / Muhammad_Jibreel_64kbps whose files are ok for busmalla for every sura without merging
      if (db.sheekhUrl[sheekhIndex].startsWith("Husary") ||
          db.sheekhUrl[sheekhIndex].startsWith("Hudhaify") ||
          db.sheekhUrl[sheekhIndex].startsWith("Ibrahim_Akhdar") ||
          db.sheekhUrl[sheekhIndex].startsWith("Yaser_Salamah") ||
          db.sheekhUrl[sheekhIndex].startsWith("khalefa_al_tunaiji") ||
          db.sheekhUrl[sheekhIndex].startsWith("Ayman_Sowaid") ||
          db.sheekhUrl[sheekhIndex].startsWith("Muhammad_AbdulKareem") ||
          db.sheekhUrl[sheekhIndex].startsWith("Hani_Rifai") ||
          db.sheekhUrl[sheekhIndex].startsWith("Abdullaah_3awwaad") ||
          db.sheekhUrl[sheekhIndex].startsWith("Abdul_Basit") ||
          db.sheekhUrl[sheekhIndex].startsWith("ahmed_ibn_ali") ||
          db.sheekhUrl[sheekhIndex].startsWith("Abu_Bakr_Ash") ||
          db.sheekhUrl[sheekhIndex].startsWith("Ahmed_Neana") ||
          db.sheekhUrl[sheekhIndex].startsWith("Salaah_AbdulRahman") ||
          db.sheekhUrl[sheekhIndex].startsWith("Salah_Al_Budair") ||
          db.sheekhUrl[sheekhIndex].startsWith("Maher_AlMuaiqly") ||
          db.sheekhUrl[sheekhIndex].startsWith("Saood_ash-Shuraym") ||
          db.sheekhUrl[sheekhIndex].startsWith("Ali_Hajjaj") ||
          db.sheekhUrl[sheekhIndex].startsWith("Yasser_Ad-Dussary") ||
          db.sheekhUrl[sheekhIndex].startsWith("Nabil_Rifa3i") ||
          db.sheekhUrl[sheekhIndex].startsWith("aziz_alili") ||
          db.sheekhUrl[sheekhIndex].startsWith("Fares_Abbad") ||
          db.sheekhUrl[sheekhIndex].startsWith("Minshawy") ||
          db.sheekhUrl[sheekhIndex].startsWith("Nasser_Alqatami") ||
          db.sheekhUrl[sheekhIndex].startsWith("mahmoud_ali_al") || // Only one with esteaatha. no file for busmalla only
          db.sheekhUrl[sheekhIndex].startsWith("Alafasy") ||
          db.sheekhUrl[sheekhIndex].startsWith("Ghamadi")) {
        filename = "001001.mp3";
      }
      else {
        if (db.sheekhUrl[sheekhIndex].startsWith("Abdullah_Basfar") ||
            db.sheekhUrl[sheekhIndex].startsWith("Akram_AlAlaqimy") ||
            db.sheekhUrl[sheekhIndex].startsWith("Ali_Jaber") ||
            db.sheekhUrl[sheekhIndex].startsWith("Muhsin_Al_Qasim") ||
            db.sheekhUrl[sheekhIndex].startsWith("Abdurrahmaan_As-Sudais")) {
          filename = "110000.mp3";
        }
        else {
          if (db.sheekhUrl[sheekhIndex].startsWith("Khaalid_Abdullaah_al")) {
            filename = "070000.mp3";
          } else {
            if (db.sheekhUrl[sheekhIndex].startsWith("Sahl_Yassin")) {
              filename = "036000.mp3";
            }
          }
        }
      }
    }

    final String src = 'https://everyayah.com/data/${db.sheekhUrl[sheekhIndex]}/$filename';
    if (repetitionCount.value > 1 && repetitionType == Repetition.aya) {
      /* LoopingAudioSource causes issues in strange cases e.g. increase repetitionCount go to next page and increase repetitionCount, error is thrown
      mediaRepetitionList.add(
        LoopingAudioSource(
          count: repetitionCount.value,
          child: AudioSource.uri(Uri.parse(src)),
        ),
      );
      */

      for (int i = 0; i < repetitionCount.value; i++) {
        playListSrc.add(src);
        mediaRepetitionList.add(AudioSource.uri(Uri.parse(src)));
      }
    } else {
      mediaList.add(
        AudioSource.uri(Uri.parse(src),
          /*
          tag: MediaItem(
            // a unique ID for each media item:
            id: filename,
            album: db.sura[sura[i] - 1],
            title: db.sheekh[sheekhIndex],
            //artUri: Uri.parse('https://example.com/albumart.jpg'),
          ),
        */
        ),
      );
      playListSrc.add(src);
    }
  }

  // play() will not work if stop() was not triggered before playlist.clear
  await player.stop();
  //await player.clearAudioSources();
  //await player.seek(Duration.zero);

  // playlist.clear will trigger player.currentIndexStream.listen with track = 0, hence locationIndex.value will be lost. the below is to remember it
  final int tmp = locationIndex.value;
  await playlist.clear();
  if (repetitionCount.value > 1 && repetitionType == Repetition.aya) {
    await playlist.addAll(mediaRepetitionList);
  } else {
    await playlist.addAll(mediaList);
  }
  locationIndex.value = tmp;
}

bool ignoreTracking = false;
Future<void> updatePlayList(ConcatenatingAudioSource playlist) async {
  ignoreTracking = true;
  if (repetitionCount.value == 1) { // reset counter i.e. remove repetition

    int tmp;
    if(isPlaying.value) { // track is only changing while playing
      tmp = track; // track is changing with any addition or removal
    } else {
      tmp = 0;
      track = 0;
    }

    // Remove repetition of the aya currently playing
    for (int i = tmp + 1; i < playListSrc.length; i++) {
      if (playListSrc[tmp] == playListSrc[i]) {
        await playlist.removeAt(i);
        playListSrc.removeAt(i);
        i--;
      }
      else { // stop once aya changed
        break;
      }
    }
    for (int i = tmp - 1; i >= 0; i--) {
      if (playListSrc[tmp] == playListSrc[i]) {
        await playlist.removeAt(i);
        playListSrc.removeAt(i);
        tmp--;
      }
      else {
        break;
      }
    }

    /* This style causes removing basmala from some pages where many sura at the same time e.g. page 602 all basmala will be removed if it was selected and repetitionCount become 1
    for (int i = 0; i < playListSrc.length; i++) {
      if (i < tmp) {
        if (playListSrc[tmp] == playListSrc[i]) {
          await playlist.removeAt(i);
          playListSrc.removeAt(i);
          tmp--;
          i--;
        }
      } else {
        if (i > tmp) {
          if (playListSrc[tmp] == playListSrc[i]) {
            await playlist.removeAt(i);
            playListSrc.removeAt(i);
            i--;
          }
        } else { //i == tmp; nothing to be done
        }
      }
    }
    */

    // Remove the repetitive from others. The current playing aya is only one now.
    for (int i = 0; i < playListSrc.length; i++) {
      for (int j = i + 1; j < playListSrc.length; j++) {
        if (playListSrc[i] == playListSrc[j]) {
          await playlist.removeAt(j);
          playListSrc.removeAt(j);
          j--;
        } else {
          break;
        }
      }
    }
  } else {
    String lastUrl = '';
    for (int i = 0; i < playListSrc.length; i++) {
      if (lastUrl == playListSrc[i]) {
        if (i == (playListSrc.length - 1)) { // last item
          await playlist.insert(i, AudioSource.uri(Uri.parse(lastUrl)));
          playListSrc.insert(i, lastUrl);
          break;
        }
      } else {
        if (i != 0) {
          await playlist.insert(i, AudioSource.uri(Uri.parse(lastUrl)));
          playListSrc.insert(i, lastUrl);
          lastUrl = playListSrc[i + 1];
        } else {
          lastUrl = playListSrc[i];
        }
      }
    }
  }
  ignoreTracking = false;
}

const int maxRepetition = 7;
final ValueNotifier<int> locationIndex = ValueNotifier<int>(-1);
final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
final ValueNotifier<int> repetitionCount = ValueNotifier<int>(1);
int repetitionIndex = 1;
int track = -1;
enum PlayerRestart { yes, no, qiraatChanged, suraChanged }
final List <String> playListSrc = [];

class QuranPageViewState extends State<QuranPageView> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> setPage(final int page) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setInt('page', page);
  }

  Future<void> readFile(String path, PlayerRestart restartPlayer) async {
    if (kDebugMode) {
      print('readFile $path $restartPlayer previousButtonEvent:$previousButtonEvent playing:${widget._player.playing} locationIndex:${locationIndex.value}');
    }

    sura.clear();
    aya.clear();
    locations.clear();

    final String fileText = await rootBundle.loadString(path);
    const LineSplitter ls = LineSplitter();
    final List<String> ayat = ls.convert(fileText);

    for (int i = 0; i < ayat.length; i++) {
      final List<String> tokens = ayat[i].split("ö");
      aya.add(int.parse(tokens[0]));
      sura.add(int.parse(tokens[1]));

      Path area = Path();
      double w = 0;
      double h = 0;
      double pageWidth = 0;
      double pageHeight = 0;

      if (tokens[2].isNotEmpty) {
        final List<String> location = tokens[2].split("-");
        for (int r = 0; r < location.length; r++) {
          final List<String> dimensions = location[r].split(",");
          if (r == 0) {
            w = double.parse(dimensions[0]);
            h = double.parse(dimensions[1]);
            pageWidth = widget.displayWidth; //.width * 0.99; // To add padding, search for 0.005 and 0.99 and re-enable it with testing
            pageHeight = pageWidth * h / w;
          }
          else {
            final double xx = double.parse(dimensions[0]) / w * pageWidth;
            final double yy = double.parse(dimensions[1]) / h * pageHeight;
            final double width = double.parse(dimensions[2]) / w * pageWidth;
            final double height = double.parse(dimensions[3]) / h * pageHeight;

            final Path region = Path();
            region.addRect(Rect.fromLTWH(xx, yy, width, height));

            area = Path.combine(PathOperation.union, area, region);
          }
        }
      }

      locations.add(area);
    }

    switch (restartPlayer) {
      case PlayerRestart.yes:
        {
          if (locationIndex.value != -1) { // playing || paused
            if (previousButtonEvent) {
              previousButtonEvent = false;
              if (widget._player.playing) {
                await prepareList(widget._player, widget._playlist);
                locationIndex.value = -1; // To refresh the selection in case the new value is similar
                await updateLocationAndSeek((sura.length - 1));
                widget._player.play();
              }
              else { // paused
                await prepareList(widget._player, widget._playlist);
                locationIndex.value = -1;
                await updateLocationAndSeek((sura.length - 1));
              }
            }
            else {
              if (widget._player.playing) {
                await prepareList(widget._player, widget._playlist);
                locationIndex.value = -1;
                await updateLocationAndSeek(0);
                widget._player.play();
              }
              else { // paused
                await prepareList(widget._player, widget._playlist);
                locationIndex.value = -1;
                await updateLocationAndSeek(0);
              }
            }
          }
          else {
            await prepareList(widget._player, widget._playlist);
            widget._player.seek(Duration.zero, index: 0);
          }
          break;
        }
      case PlayerRestart.no:
        {
          // Refresh the last selection to reflect the new dimension
          final int tmp = locationIndex.value;
          locationIndex.value = -1;
          locationIndex.value = tmp;
          widget._player.seek(Duration.zero);
          break;
        }
      case PlayerRestart.qiraatChanged:
        await prepareList(widget._player, widget._playlist);
        widget._player.seek(Duration.zero, index: 0);
        break;
      case PlayerRestart.suraChanged:
        await prepareList(widget._player, widget._playlist);
        break;
    }
  }

  Future<void> updateLocationAndSeek(int i) async {
    print('updateLocationAndSeek $i ${repetitionCount.value}');
    locationIndex.value = i;
    if (repetitionType == Repetition.aya) {
      await widget._player.seek(Duration.zero, index: (i * repetitionCount.value).toInt());
    } else {
      await widget._player.seek(Duration.zero, index: i);
    }
  }

  @override
  void initState() {
    super.initState();
    _init();

    // This one is working also
    //WidgetsBinding.instance.addPostFrameCallback((_) {_init();});
    //SchedulerBinding.instance.addPostFrameCallback((_) {_init();});
  }

  Future<void> _init() async {
    try {
      // Preloading audio is not currently supported on Linux/Web.
      await widget._player.setAudioSource(
          widget._playlist, initialIndex: 0, initialPosition: Duration.zero,
          preload: kIsWeb || defaultTargetPlatform != TargetPlatform.linux);
    } on PlayerException catch (e) {
      // Catch load errors: 404, invalid url...
      if (kDebugMode) {
        print("Error loading audio source: $e");
      }
    }

    widget._player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
          if (kDebugMode) {
            print('A stream error occurred: $e');
          }
        });

    /* New style but it is not stopped sharp at the end of Aya, you need to disable the LoopingAudioSource in prepareList
    // listen whenever reaching the end of an aya in the playlist.
    widget._player.positionDiscontinuityStream.listen((discontinuity) async {
      if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
        if(repetitionIndex > 1) {
          print('repetitionIndex: ${discontinuity.previousEvent.currentIndex} $repetitionIndex');
          repetitionIndex--;
          // https://github.com/ryanheise/just_audio/issues/380
          // https://stackoverflow.com/questions/66513675/silence-between-tracks-in-just-audio/66514017#66514017
          await Future.delayed(const Duration(milliseconds: 25), () {
            widget._player.seek(Duration.zero, index: discontinuity.previousEvent.currentIndex);
          });
        }
      }
    });
    */

    widget._player.playerStateStream.listen((playerState) async {
      if (kDebugMode) {
        print('playerStateStream $playerState playing:${playerState.playing}');
      }

      if (playerState.playing && playerState.processingState == ProcessingState.ready) {
        if (repetitionType == Repetition.aya) {
          locationIndex.value = (track / repetitionCount.value).toInt();
        } else {
          locationIndex.value = track;
        }
        isPlaying.value = true; // playing
        WakelockPlus.enable();
      } else {
        isPlaying.value = false; // paused/stopped
        WakelockPlus.disable();
      }

      if (playerState.processingState == ProcessingState.completed) {
        if (locationIndex.value == (sura.length - 1) && widget.setting.page != 603 && sura.isNotEmpty) {
          // end of page is reached
          if (repetitionType == Repetition.page && repetitionCount.value > 1) {
            await widget._player.seek(Duration.zero, index: 0);
            widget._player.play();
            repetitionCount.value--;
          } else {
            widget._pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
          }
        } else {
          locationIndex.value = -1;
          if (widget.setting.page == 603) { // End of quran
            // This will trigger the ProcessingState.completed again with playing=false. Once playing=false (regardless of ProcessingState) pressing stop() will not trigger any more events
            await widget._player.stop();
            widget._player.seek(Duration.zero, index: 0);
          }
        }
      }
    });

    /*
    widget._player.sequenceStateStream.listen((sequenceState) {
      if (kDebugMode) {
        //print('sequenceState ${sequenceState?.sequence}');
        //print('sequenceState ${sequenceState?.currentIndex}');
      }
    });
    */

    /*
    widget._player.playingStream.listen((playing) {
      if (kDebugMode) {
        print('playing $playing');
      }

      if (playing) {
        if (repetitionType == Repetition.aya) {
          locationIndex.value = (track / repetitionCount.value).toInt();
        } else {
          locationIndex.value = track;
        }
        isPlaying.value = true;
      } else {
        isPlaying.value = false;
      }
    });
    */

    widget._player.currentIndexStream.listen((index) {
      if (kDebugMode) {
        print('track $index ignoreTracking:$ignoreTracking');
      }

      if (index == null) {
        track = -1;
        return;
      }

      if (ignoreTracking) {
        return;
      }

      track = index;

      // To cover the case when playing or in pause
      if (widget._player.playing) {
        if (repetitionType == Repetition.aya) {
          locationIndex.value = (track / repetitionCount.value).toInt();
        } else {
          locationIndex.value = track;
        }
      }
    });

    if (widget.setting.qiraat == db.qiraatPath.elementAt(0)) { // Only hafs is done. also missing aya files in other qiraat
      await readFile('db/${widget.setting.page + 1}', PlayerRestart.yes);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.builder.call(context, jumpToPage);

    if (widget.setting.qiraatChanged && widget.setting.qiraat == db.qiraatPath.elementAt(0)) {
      readFile('db/${widget.setting.page + 1}', PlayerRestart.qiraatChanged);
      widget.setting.qiraatChanged = false;
    }

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        if (widget.setting.qiraat == db.qiraatPath.elementAt(0)) {
          readFile('db/${widget.setting.page + 1}', PlayerRestart.no);
        }
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: PageView.builder(
          onPageChanged: (int page) async {
            widget.setting.page = page;
            if (kDebugMode) {
              print('page ${widget.setting.page + 1}');
            }

            // this page variable is the new page and will change before the pageController fully reaches the full, rounded int value
            setPage(widget.setting.page);

            if (widget.setting.qiraat == db.qiraatPath.elementAt(0)) {
              if (widget.setting.suraChanged != -1) {
                await readFile('db/${widget.setting.page + 1}', PlayerRestart.suraChanged);
                await widget._player.seek(Duration.zero, index: db.suraLocationIndex.elementAt(widget.setting.suraChanged) * repetitionCount.value);
                if (locationIndex.value != -1) {
                  locationIndex.value = db.suraLocationIndex.elementAt(widget.setting.suraChanged);
                  widget._player.play();
                }
                widget.setting.suraChanged = -1;
              }
              else {
                readFile('db/${widget.setting.page + 1}', PlayerRestart.yes);
              }
            }
          },
          allowImplicitScrolling: true,
          controller: widget._pageController,
          padEnds: false,
          itemCount: 604,
          itemBuilder: (context, position) {
            final String page = (position + 1).toString();
            return Container(
              alignment: Alignment.center,
              //padding: EdgeInsets.all(w * .005),
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: GestureDetector(
                  onLongPressStart: (details) async {
                    if (widget.setting.qiraat == db.qiraatPath.elementAt(0)) {
                      for (int e = 0; e < locations.length; e++) {
                        final Path area = locations[e];
                        if (area.contains(Offset(details.localPosition.dx, details.localPosition.dy))) {
                          await updateLocationAndSeek(e);
                          widget._player.play();
                          break;
                        }
                      }
                    }
                  },
                  child: Stack(
                    children: <Widget>[
                      ((kIsWeb && kDebugMode) ||
                          defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.android)
                          ? ((widget.setting.qiraat == db.qiraatPath.elementAt(
                          0)) ?
                      SvgPicture.asset(
                        width: widget.displayWidth /* * 0.99 */,
                        '${widget.setting.qiraat}/$page.svg',
                        colorFilter: widget.setting.nightTheme
                            ? const ColorFilter
                            .matrix(
                            [
                              -1, 0, 0, 0, 255,
                              0, -1, 0, 0, 255,
                              0, 0, -1, 0, 255,
                              0, 0, 0, 1, 0
                            ])
                            : null,
                      ) :
                      SvgPicture.network(
                        width: widget.displayWidth /* * 0.99*/,
                        'https://haq.app/assets/${widget.setting.qiraat}/$page.svg',
                        colorFilter: widget.setting.nightTheme
                            ? const ColorFilter.matrix([
                          -1, 0, 0, 0, 255,
                          0, -1, 0, 0, 255,
                          0, 0, -1, 0, 255,
                          0, 0, 0, 1, 0
                        ]) : null,
                        placeholderBuilder: (BuildContext context) =>
                            Container(
                                padding: const EdgeInsets.all(30.0),
                                //child: const Icon(Icons.cloud_download_outlined, size: 80.0, color: Color.fromRGBO(0, 0, 0, 0.40),)),
                                child: const CircularProgressIndicator()),
                      )
                      ) : SvgPicture.asset( // Covers linux/win/Web
                        width: widget.displayWidth /* * 0.99 */,
                        '${widget.setting.qiraat}/$page.svg',
                        colorFilter: widget.setting.nightTheme
                            ? const ColorFilter
                            .matrix(
                            [
                              -1, 0, 0, 0, 255,
                              0, -1, 0, 0, 255,
                              0, 0, -1, 0, 255,
                              0, 0, 0, 1, 0
                            ])
                            : null,
                      ),
                      (widget.setting.qiraat == db.qiraatPath.elementAt(0))
                          ? ValueListenableBuilder<int>(
                        valueListenable: locationIndex,
                        builder: (context, value, child) {
                          return Positioned.fill(
                            child: CustomPaint(
                              painter: MyPainter(
                                  (value != -1 && locations.isNotEmpty && position == widget.setting.page) ?
                                  locations[value] :
                                  Path(), widget.setting.nightTheme),
                            ),
                          );
                        },
                      ) : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void jumpToPage(int page) {
    widget._pageController.jumpToPage(page);
  }
}