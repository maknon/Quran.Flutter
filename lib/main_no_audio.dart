import 'db.dart';
import 'services.dart';

import 'dart:ui';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

typedef MyBuilder = void Function(BuildContext context, void Function(int page) methodFromChild);

void main() {
  runApp(
    MaterialApp(
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
                  false, qiraatPath.elementAt(0), snapshot.data ?? 0),
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

  Setting(this.nightTheme, this.qiraat, this.page);
}

class QuranApp extends StatefulWidget {
  final Setting setting;

  const QuranApp({super.key, required this.setting});

  @override
  State<StatefulWidget> createState() {
    return QuranAppState();
  }
}

class QuranAppState extends State<QuranApp> {
  QuranAppState();

  late TextEditingController pageTextController;

  @override
  void initState() {
    super.initState();
    pageTextController = TextEditingController();
  }

  @override
  void dispose() {
    pageTextController.dispose();
    super.dispose();
  }

  bool showAppbar = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        //extendBody: true,
        appBar: showAppbar ? AppBar(
          //forceMaterialTransparency: true,
          backgroundColor: widget.setting.nightTheme
              ? Colors.black
              : const Color
              .fromRGBO(0, 0, 0, 0.40),
          actions: [
            if(kIsWeb && defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform !=
                    TargetPlatform.macOS) // ipad is considered macOS !
              IconButton(
                  color: const Color.fromRGBO(255, 255, 255, 0.90),
                  onPressed: () =>
                  {
                    launch(
                        'https://play.google.com/store/apps/details?id=com.maknoon.quran',
                        isNewTab: true)
                  }, icon: const Icon(Icons.android)),
            if(kIsWeb && defaultTargetPlatform != TargetPlatform.android)
              IconButton(
                  color: const Color.fromRGBO(255, 255, 255, 0.90),
                  onPressed: () =>
                  {
                  }, icon: const Icon(Icons.apple)),
            if(kIsWeb)
              IconButton(
                  color: const Color.fromRGBO(255, 255, 255, 0.90),
                  onPressed: () =>
                  {
                    launch(
                        'https://maknoon.com/download/quran/quran_${widget
                            .setting.qiraat}_m.pdf',
                        isNewTab: true)
                  }, icon: const Icon(Icons.picture_as_pdf_outlined)),
            IconButton(
                color: const Color.fromRGBO(255, 255, 255, 0.90),
                onPressed: () =>
                {
                  setState(() {
                    widget.setting.nightTheme = !widget.setting.nightTheme;
                  })
                }, icon: const Icon(Icons.nightlight)),
            //if(kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)
            PopupMenuButton(
                tooltip: 'القراءات',
                iconColor: const Color.fromRGBO(255, 255, 255, 0.90),
                icon: const Icon(Icons.menu_book),
                itemBuilder: (context) =>
                    qiraat.map((e) => PopupMenuItem(value: e, child: Text(e)))
                        .toList(),
                onSelected: (value) {
                  setState(() {
                    final int v = qiraat.indexOf(value);
                    widget.setting.qiraat = qiraatPath.elementAt(v);
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
                            title: const Text("الذهاب إلى"),
                            content: TextField(
                              autofocus: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                NumericalRangeFormatter(min: 1, max: 604),
                              ],
                              keyboardType: TextInputType.number,
                              controller: pageTextController,
                              decoration: const InputDecoration(
                                  hintText: 'الصفحة'),
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
                itemBuilder: (context) =>
                    sura.map((e) => PopupMenuItem(value: e, child: Text(e)))
                        .toList(),
                onSelected: (value) {
                  final int v = sura.indexOf(value);
                  widget.setting.page = suraPage.elementAt(v) - 1;
                  jumpTo.call(widget.setting
                      .page); // << this will execute the methodFromChild
                }
            ),
            PopupMenuButton(
                tooltip: 'الجزء',
                iconColor: const Color.fromRGBO(255, 255, 255, 0.90),
                icon: const Icon(Icons.layers),
                itemBuilder: (context) =>
                    juz.map((e) => PopupMenuItem(value: e, child: Text(e)))
                        .toList(),
                onSelected: (value) {
                  int v = juz.indexOf(value);
                  widget.setting.page = juzPage.elementAt(v) - 1;
                  jumpTo.call(widget.setting
                      .page); // << this will execute the methodFromChild
                }
            ),
            if(kIsWeb)
              IconButton(
                  color: const Color.fromRGBO(255, 255, 255, 0.90),
                  onPressed: () =>
                  {
                    launch('https://www.maknoon.com/community/forums/16',
                        isNewTab: true)
                  }, icon: const Icon(Icons.home)),
          ],
        ) : null,
        backgroundColor: widget.setting.nightTheme
            ? Colors.black
            : const Color
            .fromRGBO(255, 255, 242, 1.0),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              showAppbar = !showAppbar;
            });
          },
          child: QuranPageView(
            builder: (BuildContext context,
                void Function(int page) methodFromChild) {
              jumpTo = methodFromChild;
            }, setting: widget.setting,
          ),
        ),
      ),
    );
  }

  late void Function(int page) jumpTo;

  void goTo() {
    try {
      int page = int.parse(
          pageTextController.text);

      if (page > 604 || page < 1) {
        throw const FormatException();
      }

      widget.setting.page = page - 1;
      jumpTo.call(widget.setting
          .page);
      Navigator.pop(context);
    } on FormatException {
      Navigator.pop(context);
      /* No need since the user is not able to enter anything except 1 - 604
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return const Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  title: Text("خطأ"),
                  content: Text(
                      "الرقم من 1 إلى 604"),
                )
            );
          }
      );
      */
    }
    pageTextController.text = '';
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

  const QuranPageView(
      {super.key, required this.setting, required this.builder});

  @override
  State<StatefulWidget> createState() {
    return QuranPageViewState();
  }
}

class QuranPageViewState extends State<QuranPageView> {
  late PageController controller;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> setPage(final int page) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setInt('page', page);
  }

  @override
  void initState() {
    super.initState();
    controller = PageController(
        initialPage: widget.setting.page,
        keepPage: false
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.builder.call(context, jumpToPage);
    final double w = MediaQuery
        .of(context)
        .size
        .width;

    return PageView.builder(
      onPageChanged: (int page) {
        // this page variable is the new page and will change before the pageController fully reaches the full, rounded int value
        setPage(page);
      },
      allowImplicitScrolling: true,
      controller: controller,
      itemCount: 604,
      itemBuilder: (context, position) {
        final String page = (position + 1).toString();
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(w * .005),
          child: SingleChildScrollView(
            child: (kIsWeb ||
                (widget.setting.qiraat != qiraatPath.elementAt(0) &&
                    (defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.android)))
                ? SvgPicture
                .network(
              width: w,
              'https://haq.app/${widget.setting.qiraat}/$page.svg',
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
                : SvgPicture.asset(
              width: w,
              '${widget.setting.qiraat}/$page.svg',
              colorFilter: widget.setting.nightTheme ? const ColorFilter.matrix(
                  [
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0
                  ]) : null,
            ),
          ),
        );
      },
      padEnds: false,
    );
  }

  void jumpToPage(int page) {
    controller.jumpToPage(page);
  }
}