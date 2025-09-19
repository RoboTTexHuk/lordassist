import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart' show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'main.dart' show MainHandler, WebPage, PortalView, ScreenPortal, GateVortex, ZxHubView, hvViewModel, crHarbor;

// FCM Background Handler
@pragma('vm:entry-point')
Future<void> zxq_bg_bus(RemoteMessage x_msg) async {
  print("Message ID: ${x_msg.messageId}");
  print("Message Data: ${x_msg.data}");
}

class QuarkPane extends StatefulWidget with WidgetsBindingObserver {
  String seedAxis;
  QuarkPane(this.seedAxis, {super.key});
  @override
  State<QuarkPane> createState() => _QuarkPaneState(seedAxis);
}

class _QuarkPaneState extends State<QuarkPane> with WidgetsBindingObserver {
  _QuarkPaneState(this._axisNow);

  late InAppWebViewController _wvCore;
  String? _tokFcm;
  String? _gid;
  String? _inst;
  String? _plat;
  String? _osv;
  String? _appv;
  bool _pushOn = true;
  bool _busy = false;
  var _gate = true;
  String _axisNow;
  DateTime? _napAt;

  // внешний мир (tg/wa/bnl)
  final Set<String> _exHosts = {
    't.me', 'telegram.me', 'telegram.dog',
    'wa.me', 'api.whatsapp.com', 'chat.whatsapp.com',
    'bnl.com', 'www.bnl.com',
  };
  final Set<String> _exSchemes = {'tg', 'telegram', 'whatsapp', 'bnl'};

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState z) {
    if (z == AppLifecycleState.paused) {
      _napAt = DateTime.now();
    }
    if (z == AppLifecycleState.resumed) {
      if (Platform.isIOS && _napAt != null) {
        final now = DateTime.now();
        final span = now.difference(_napAt!);
        if (span > const Duration(minutes: 25)) {
          _hardFlip();
        }
      }
      _napAt = null;
    }
  }

  void _hardFlip() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>  crHarbor(signal: "",),
        ),
            (route) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    FirebaseMessaging.onBackgroundMessage(zxq_bg_bus);
    _spinAf();
    _wireFcm();
    _scanGizmo();
    _busFcmSide();
    _bindBell();

    Future.delayed(const Duration(seconds: 2), () {
      // зарезервировано для поздней инициализации
    });
    Future.delayed(const Duration(seconds: 6), () {

    });
  }

  void _busFcmSide() {
    FirebaseMessaging.onMessage.listen((RemoteMessage p) {
      if (p.data['uri'] != null) {
        _hopTo(p.data['uri'].toString());
      } else {
        _snapBack();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage p) {
      if (p.data['uri'] != null) {
        _hopTo(p.data['uri'].toString());
      } else {
        _snapBack();
      }
    });
  }

  void _hopTo(String lane) async {
    if (_wvCore != null) {
      await _wvCore.loadUrl(
        urlRequest: URLRequest(url: WebUri(lane)),
      );
    }
  }

  void _snapBack() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (_wvCore != null) {
        _wvCore.loadUrl(
          urlRequest: URLRequest(url: WebUri(_axisNow)),
        );
      }
    });
  }

  Future<void> _wireFcm() async {
    FirebaseMessaging h = FirebaseMessaging.instance;
    NotificationSettings s = await h.requestPermission(alert: true, badge: true, sound: true);
    _tokFcm = await h.getToken();
  }

  AppsflyerSdk? _afSdk;
  String _afBlob = "";
  String _afId = "";

  void _spinAf() {
    final AppsFlyerOptions opts = AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6745261464",
      showDebug: true,
    );
    _afSdk = AppsflyerSdk(opts);
    _afSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _afSdk?.startSDK(
      onSuccess: () => print("AppsFlyer OK"),
      onError: (int c, String m) => print("AppsFlyer Error: $c $m"),
    );
    _afSdk?.onInstallConversionData((d) {
      setState(() {
        _afBlob = d.toString();
        _afId = d['payload']['af_status'].toString();
      });
    });
    _afSdk?.getAppsFlyerUID().then((v) {
      setState(() {
        _afId = v.toString();
      });
    });
  }


  Future<void> _scanGizmo() async {
    try {
      final z = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await z.androidInfo;
        _gid = a.id;
        _plat = "android";
        _inst = a.version.release;
      } else if (Platform.isIOS) {
        final i = await z.iosInfo;
        _gid = i.identifierForVendor;
        _plat = "ios";
        _inst = i.systemVersion;
      }
      final pkg = await PackageInfo.fromPlatform();
      _osv = Platform.localeName.split('_')[0];
      _appv = timezone.local.name;
    } catch (e) {
      debugPrint("Device Info Error: $e");
    }
  }

  void _bindBell() {
    MethodChannel('com.example.fcm/notification').setMethodCallHandler((call) async {
      if (call.method == "onNotificationTap") {
        final Map<String, dynamic> x = Map<String, dynamic>.from(
          call.arguments,
        );
        print("URI data" + x['uri'].toString());
        if (x["uri"] != null && !x["uri"].contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => QuarkPane(x["uri"])),
                (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _bindBell();

    final night = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: night ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                disableDefaultErrorPage: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
              ),
              initialUrlRequest: URLRequest(url: WebUri(_axisNow)),
              onWebViewCreated: (c) {
                _wvCore = c;
                _wvCore.addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback: (args) {
                    print("JS Args: $args");
                    return args.reduce((v, e) => v + e);
                  },
                );
              },
              onLoadStart: (c, u) async {
                if (u != null) {
                  if (_looksLikeMail(u)) {
                    try {
                      await c.stopLoading();
                    } catch (_) {}
                    final m = _toMailto(u);
                    await _openMailWeb(m);
                    return;
                  }
                  final s = u.scheme.toLowerCase();
                  if (s != 'http' && s != 'https') {
                    try {
                      await c.stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (c, u) async {
                await c.evaluateJavascript(
                  source: "console.log('Hello from JS!');",
                );
              },
              shouldOverrideUrlLoading: (c, nav) async {
                final u = nav.request.url;
                if (u == null) return NavigationActionPolicy.ALLOW;

                if (_looksLikeMail(u)) {
                  final m = _toMailto(u);
                  await _openMailWeb(m);
                  return NavigationActionPolicy.CANCEL;
                }

                final sch = u.scheme.toLowerCase();

                if (sch == 'mailto') {
                  await _openMailWeb(u);
                  return NavigationActionPolicy.CANCEL;
                }

                if (_isOuterWorld(u)) {
                  await _openWeb(_toOuterHttp(u));
                  return NavigationActionPolicy.CANCEL;
                }

                if (sch != 'http' && sch != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (c, req) async {
                final u = req.request.url;
                if (u == null) return false;

                if (_looksLikeMail(u)) {
                  final m = _toMailto(u);
                  await _openMailWeb(m);
                  return false;
                }

                final sch = u.scheme.toLowerCase();

                if (sch == 'mailto') {
                  await _openMailWeb(u);
                  return false;
                }

                if (_isOuterWorld(u)) {
                  await _openWeb(_toOuterHttp(u));
                  return false;
                }

                if (sch == 'http' || sch == 'https') {
                  c.loadUrl(urlRequest: URLRequest(url: u));
                }
                return false;
              },
            ),
            if (_busy)
              Visibility(
                visible: !_busy,
                child: SizedBox.expand(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                        strokeWidth: 8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _looksLikeMail(Uri u) {
    final s = u.scheme;
    if (s.isNotEmpty) return false;
    final raw = u.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  Uri _toMailto(Uri u) {
    final full = u.toString();
    final bits = full.split('?');
    final who = bits.first;
    final qp = bits.length > 1 ? Uri.splitQueryString(bits[1]) : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: who,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  bool _isOuterWorld(Uri u) {
    final sch = u.scheme.toLowerCase();
    if (_exSchemes.contains(sch)) return true;

    if (sch == 'http' || sch == 'https') {
      final h = u.host.toLowerCase();
      if (_exHosts.contains(h)) return true;
    }
    return false;
  }

  Uri _toOuterHttp(Uri u) {
    final sch = u.scheme.toLowerCase();

    if (sch == 'tg' || sch == 'telegram') {
      final qp = u.queryParameters;
      final domain = qp['domain'];
      if (domain != null && domain.isNotEmpty) {
        return Uri.https('t.me', '/$domain', {
          if (qp['start'] != null) 'start': qp['start']!,
        });
      }
      final path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('t.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if (sch == 'whatsapp') {
      final qp = u.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${_justDigits(phone)}', {
          if (text != null && text.isNotEmpty) 'text': text,
        });
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if (sch == 'bnl') {
      final newPath = u.path.isNotEmpty ? u.path : '';
      return Uri.https('bnl.com', '/$newPath', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    return u;
  }

  Future<bool> _openMailWeb(Uri m) async {
    final g = _gmailize(m);
    return await _openWeb(g);
  }

  Uri _gmailize(Uri m) {
    final qp = m.queryParameters;
    final params = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (m.path.isNotEmpty) 'to': m.path,
      if ((qp['subject'] ?? '').isNotEmpty) 'su': qp['subject']!,
      if ((qp['body'] ?? '').isNotEmpty) 'body': qp['body']!,
      if ((qp['cc'] ?? '').isNotEmpty) 'cc': qp['cc']!,
      if ((qp['bcc'] ?? '').isNotEmpty) 'bcc': qp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', params);
  }

  Future<bool> _openWeb(Uri u) async {
    try {
      if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('openInAppBrowser error: $e; url=$u');
      try {
        return await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  String _justDigits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
}