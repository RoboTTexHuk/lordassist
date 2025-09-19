// ignore_for_file: unused_field, unused_local_variable, prefer_const_constructors, depend_on_referenced_packages, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, HttpHeaders, HttpClient;

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as af_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as r;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:lordsassistant/puskl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;
const String _kLoadedEventPrefKey = "loaded_event_sent_once";
const String kStatUrl = "https://api.lord-assis.cfd/stat";
// ============================================================================
// DI контейнер
// ============================================================================
final gxKeg = GetIt.instance;

void gxPrime() {
  if (!gxKeg.isRegistered<FlutterSecureStorage>()) {
    gxKeg.registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage());
  }
  if (!gxKeg.isRegistered<Logger>()) {
    gxKeg.registerSingleton<Logger>(Logger());
  }
  if (!gxKeg.isRegistered<Connectivity>()) {
    gxKeg.registerSingleton<Connectivity>(Connectivity());
  }
}

// ============================================================================
// Слой данных (Data Layer) + Сеть
// ============================================================================
class wvPulseWire {
  Future<bool> zing() async {
    var c = await gxKeg<Connectivity>().checkConnectivity();
    return c != ConnectivityResult.none;
  }

  Future<void> blast(String u, Map<String, dynamic> d) async {
    try {
      await http.post(Uri.parse(u), body: jsonEncode(d));
    } catch (e) {
      gxKeg<Logger>().e("blast-err: $e");
    }
  }
}

// ============================================================================
// Device/App Info (переименовано)
// ============================================================================
class fxGizmoSheet {
  String? pA; // device_id
  String? pB = "x-one-off"; // instance/session id
  String? pC; // platform
  String? pD; // os version
  String? pE; // app version
  String? pF; // language
  String? pG; // timezone
  bool pH = true; // push enabled

  Future<void> crank() async {
    final di = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final x = await di.androidInfo;
      pA = x.id;
      pC = "android";
      pD = x.version.release;
    } else if (Platform.isIOS) {
      final x = await di.iosInfo;
      pA = x.identifierForVendor;
      pC = "ios";
      pD = x.systemVersion;
    }
    final appInfo = await PackageInfo.fromPlatform();
    pE = appInfo.version;
    pF = Platform.localeName.split('_')[0];
    pG = tz_zone.local.name;
    pB = "slot-${DateTime.now().millisecondsSinceEpoch}";
  }

  Map<String, dynamic> pack({String? jet}) => {
    "fcm_token": jet ?? 'missing_token',
    "device_id": pA ?? 'missing_id',
    "app_name": "lordsassistant",
    "instance_id": pB ?? 'missing_session',
    "platform": pC ?? 'missing_system',
    "os_version": pD ?? 'missing_build',
    "app_version": pE ?? 'missing_app',
    "language": pF ?? 'en',
    "timezone": pG ?? 'UTC',
    "push_enabled": pH,
  };
}

// ============================================================================
// AppsFlyer оболочка (переименовано) + ChangeNotifier для MVVM
// ============================================================================
class kxSkylark with ChangeNotifier {
  af_core.AppsFlyerOptions? _cfg;
  af_core.AppsflyerSdk? _sdk;

  String mId = "";
  String mBlob = "";

  void ignite(VoidCallback nudge) {
    final cfg = af_core.AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6752774975",
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );
    _cfg = cfg;
    _sdk = af_core.AppsflyerSdk(cfg);

    _sdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _sdk?.startSDK(
      onSuccess: () => gxKeg<Logger>().i("Skylark up"),
      onError: (int c, String m) => gxKeg<Logger>().e("Skylark err $c: $m"),
    );
    _sdk?.onInstallConversionData((res) {
      mBlob = res.toString();
      nudge();
      notifyListeners();
    });
    _sdk?.getAppsFlyerUID().then((v) {
      mId = v.toString();
      nudge();
      notifyListeners();
    });
  }
}

// ============================================================================
// Riverpod провайдеры (MVVM ViewModel-хранилище)
// ============================================================================
final vmGizmo = r.FutureProvider<fxGizmoSheet>((ref) async {
  final z = fxGizmoSheet();
  await z.crank();
  return z;
});

final vmSkylark = p.ChangeNotifierProvider(create: (_) => kxSkylark());

// ============================================================================
// Упрощённый BLoC (сигнал готовности) — переименовано
// ============================================================================
enum rtWaveIn { ping }
enum rtWaveOut { idle, arm, fire, cool }

class rtWaveBloc extends Bloc<rtWaveIn, rtWaveOut> {
  rtWaveBloc() : super(rtWaveOut.idle) {
    on<rtWaveIn>((e, emit) async {
      emit(rtWaveOut.arm);
    });
  }
}

// ============================================================================
// Новый «лоудер»: слово LORDS переливается с оранжевого до белого на чёрном фоне
// ============================================================================
class LordsFluxLoader extends StatefulWidget {
  const LordsFluxLoader({Key? key}) : super(key: key);

  @override
  State<LordsFluxLoader> createState() => _LordsFluxLoaderState();
}

class _LordsFluxLoaderState extends State<LordsFluxLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Color?> _tone;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);

    _tone = ColorTween(
      begin: Colors.orange,
      end: Colors.white,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: AnimatedBuilder(
        animation: _tone,
        builder: (context, _) {
          return Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Text(
              "LORDS",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: _tone.value,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// FCM бекграунд (переименовано только лог)
// ============================================================================
@pragma('vm:entry-point')
Future<void> orionBgFcm(RemoteMessage m) async {
  gxKeg<Logger>().i("bg-ping: ${m.messageId}");
  gxKeg<Logger>().i("bg-payload: ${m.data}");
}

// ============================================================================
// Экран-запуск (обновлено под новый лоудер) — MVP + MVVM склейка
// ============================================================================
class ztFoyer extends StatefulWidget {
  const ztFoyer({Key? key}) : super(key: key);

  @override
  State<ztFoyer> createState() => _ztFoyerState();
}

class _ztFoyerState extends State<ztFoyer> {
  final _pipe = vxNimbus();
  bool _once = false;
  Timer? _fire;
  bool _muteLoader = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _pipe.hook((sig) {
      _ship(sig);
    });

    _fire = Timer(const Duration(seconds: 8), () => _ship(''));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _muteLoader = true);
    });
  }

  void _ship(String sig) {
    if (_once) return;
    _once = true;
    _fire?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => crHarbor(signal: sig),
      ),
    );
  }

  @override
  void dispose() {
    _fire?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_muteLoader) const LordsFluxLoader(),
          if (_muteLoader) const Center(child: LordsFluxLoader()),
        ],
      ),
    );
  }
}

// ============================================================================
// FCM «мост» (переименовано), остаётся аналогичный функционал
// ============================================================================
class vxNimbus extends ChangeNotifier {
  void hook(Function(String sig) tap) {
    const MethodChannel('com.example.fcm/token').setMethodCallHandler((call) async {
      if (call.method == 'setToken') {
        final String s = call.arguments as String;
        tap(s);
      }
    });
  }
}

// ============================================================================
// MVP Presenter + MVVM ViewModel (мост к WebView экрану)
// ============================================================================
class hvViewModel with ChangeNotifier {
  final fxGizmoSheet gizmo;
  final kxSkylark skylark;

  hvViewModel({required this.gizmo, required this.skylark});

  Map<String, dynamic> emitDeviceMap(String? token) => gizmo.pack(jet: token);

  Map<String, dynamic> emitAfMap(String? token) {
    return {
      "content": {
        "af_data": skylark.mBlob,
        "af_id": skylark.mId,
        "fb_app_name": "lordsassistant",
        "app_name": "lordsassistant",
        "deep": null,
        "bundle_identifier": "com.koplg.lordsassistant",
        "app_version": "1.0.0",
        "apple_id": "6752774975",
        "fcm_token": token ?? "no_token",
        "device_id": gizmo.pA ?? "no_device",
        "instance_id": gizmo.pB ?? "no_instance",
        "platform": gizmo.pC ?? "no_type",
        "os_version": gizmo.pD ?? "no_os",
        "app_version": gizmo.pE ?? "no_app",
        "language": gizmo.pF ?? "en",
        "timezone": gizmo.pG ?? "UTC",
        "push_enabled": gizmo.pH,
        "useruid": skylark.mId,
      },
    };
  }
}

class hvPresenter {
  final hvViewModel model;
  final InAppWebViewController Function() webGetter;

  hvPresenter({required this.model, required this.webGetter});

  Future<void> pushDeviceLocalStorage(String? token) async {
    final m = model.emitDeviceMap(token);
    await webGetter().evaluateJavascript(source: '''
      localStorage.setItem('app_data', JSON.stringify(${jsonEncode(m)}));
    ''');
  }

  Future<void> pushAfSendRaw(String? token) async {
    final payload = model.emitAfMap(token);
    final jsonString = jsonEncode(payload);
    gxKeg<Logger>().i("SendRawData: $jsonString");
    await webGetter().evaluateJavascript(
      source: "sendRawData(${jsonEncode(jsonString)});",
    );
  }
}

// ============================================================================
// Главный WebView экран — переименовано
// ============================================================================
Future<String> resolveFinalUrl(String startUrl, {int maxHops = 10}) async {
  final client = HttpClient();
  client.userAgent = 'Mozilla/5.0 (Flutter; dart:io HttpClient)';

  try {
    var current = Uri.parse(startUrl);
    for (int i = 0; i < maxHops; i++) {
      final req = await client.getUrl(current);
      req.followRedirects = false; // сами контролируем редиректы
      final res = await req.close();

      // Если ответ 3xx и есть Location — шагаем дальше
      if (res.isRedirect) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null || loc.isEmpty) break;

        // Бывает относительный Location — резолвим к текущему
        final next = Uri.parse(loc);
        current = next.hasScheme ? next : current.resolveUri(next);
        continue;
      }

      // Не редирект — это финальный URL
      return current.toString();
    }
    // Достигли лимита редиректов — возвращаем последнее известное
    return current.toString();
  } catch (e) {
    debugPrint("resolveFinalUrl error: $e");
    // В случае ошибки возвращаем исходный
    return startUrl;
  } finally {
    client.close(force: true);
  }
}
Future<void> _postStat({
  required String event,
  required int timeStart,
  required String url,
  required int timefinsih,
  required String appSid,
  int? firstPageLoadTs,
}) async {
  try {

    final finalUrl = await resolveFinalUrl(url);
    final payload = {
      "event": event,
      "timestart": timeStart, // ms since epoch
      "timefinsh": timefinsih, // ms since epoch
      "url":  finalUrl,
      "appleID":"6752774975",
      //  "afid": appSid, // сюда передаём AppsFlyerID
      "open_count": appSid +"/"+ timeStart.toString(),
    };

    print("loadingstatinsic $payload");
    final res = await http.post(
      Uri.parse("$kStatUrl/$appSid"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    print(" ur _loaded"+"$kStatUrl/$appSid");
    debugPrint("_postStat status=${res.statusCode} body=${res.body}");
  } catch (e) {
    debugPrint("_postStat error: $e");
  }
}
class crHarbor extends StatefulWidget {
  final String? signal;
  const crHarbor({super.key, required this.signal});

  @override
  State<crHarbor> createState() => _crHarborState();
}

class _crHarborState extends State<crHarbor> with WidgetsBindingObserver {
  late InAppWebViewController _dock;
  bool _spin = false;
  final String _axis = "https://api.lord-assis.cfd/";
  final fxGizmoSheet _gear = fxGizmoSheet();
  final kxSkylark _bird = kxSkylark();

  int _tick = 0;
  DateTime? _sleepAt;
  bool _veil = false;
  double _meter = 0.0;
  late Timer _meterT;
  final int _warm = 6;
  bool _startCover = true;

  bool _loadedEventSent = false;


  int? firstPageLoadTs;
  Future<void> _loadLoadedFlag() async {
    final sp = await SharedPreferences.getInstance();
    _loadedEventSent = sp.getBool(_kLoadedEventPrefKey) ?? false;
  }

  Future<void> _saveLoadedFlag() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoadedEventPrefKey, true);
    _loadedEventSent = true;
  }
    // Только один раз за всё время установки
  Future<void> postLoadedOnce({required String url, required int timestart}) async {
    if (_loadedEventSent) {
     print("Loaded already sent, skipping");
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _postStat(
      event: "Loaded",
      timeStart: timestart,
      timefinsih: now,
      url: url,
      appSid: _bird.mId, // <-- используем фактический AppsFlyerID
      firstPageLoadTs: firstPageLoadTs,
    );
    await _saveLoadedFlag();
  }
  // платформенные схемы/хосты
  final Set<String> _proto = {
    'tg', 'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
  };

  final Set<String> _dwell = {
    't.me', 'telegram.me', 'telegram.dog',
    'wa.me', 'api.whatsapp.com', 'chat.whatsapp.com',
    'm.me',
    'signal.me',
    'bnl.com', 'www.bnl.com',
  };

  // MVP + MVVM
  hvPresenter? _present;
  hvViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    firstPageLoadTs = DateTime.now().millisecondsSinceEpoch;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _startCover = false);
    });
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _veil = true;
      });
    });

    _bootStrap();
  }

  void _bootStrap() {
    _bootMeter();
    _armFcmBus();
    _bird.ignite(() => setState(() {}));
    _bindNotifBridge();
    _prepGear();

    Future.delayed(const Duration(seconds: 6), () async {
      await _sendGear();
      await _sendWing();
    });
  }

  void _armFcmBus() {
    FirebaseMessaging.onMessage.listen((msg) {
      final link = msg.data['uri'];
      if (link != null) {
        _hop(link.toString());
      } else {
        _spinUp();
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final link = msg.data['uri'];
      if (link != null) {
        _hop(link.toString());
      } else {
        _spinUp();
      }
    });
  }

  void _bindNotifBridge() {
    MethodChannel('com.example.fcm/notification').setMethodCallHandler((call) async {
      if (call.method == "onNotificationTap") {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(call.arguments);
        final targetUrl = payload["uri"];
        if (payload["uri"] != null && !payload["uri"].contains("Нет URI")) {
          if (!mounted) return;
          // Аналог RandomWidget(targetUrl) — заменим на просто переход в WebView
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => QuarkPane( payload["uri"])),
                (route) => false,
          );
          // А затем загрузим целевой URL
          Future.delayed(Duration(milliseconds: 300), () {
            try {
              _dock.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
            } catch (_) {}
          });
        }
      }
    });
  }

  Future<void> _prepGear() async {
    try {
      await _gear.crank();
      await _askPerm();
      // MVP/MVVM инициализация
      _viewModel = hvViewModel(gizmo: _gear, skylark: _bird);
      _present = hvPresenter(model: _viewModel!, webGetter: () => _dock);

      if (mounted) {
        if (_dock != null) {
          await _sendGear();
        }
      }
    } catch (e) {
      gxKeg<Logger>().e("prep-gear-fail: $e");
    }
  }

  Future<void> _askPerm() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  void _hop(String link) async {
    if (_dock != null) {
      await _dock.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
    }
  }

  void _spinUp() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (_dock != null) {
        _dock.loadUrl(urlRequest: URLRequest(url: WebUri(_axis)));
      }
    });
  }

  Future<void> _sendGear() async {
    gxKeg<Logger>().i("TOKEN ship ${widget.signal}");
    setState(() => _spin = true);
    try {
      await _present?.pushDeviceLocalStorage(widget.signal);
    } finally {
      setState(() => _spin = false);
    }
  }

  Future<void> _sendWing() async {
    await _present?.pushAfSendRaw(widget.signal);
  }

  void _bootMeter() {
    int n = 0;
    _meter = 0.0;
    _meterT = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() {
        n++;
        _meter = n / (_warm * 10);
        if (_meter >= 1.0) {
          _meter = 1.0;
          _meterT.cancel();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _sleepAt = DateTime.now();
    }
    if (s == AppLifecycleState.resumed) {
      if (Platform.isIOS && _sleepAt != null) {
        final now = DateTime.now();
        final dur = now.difference(_sleepAt!);
        if (dur > const Duration(minutes: 25)) {
          _reframe();
        }
      }
      _sleepAt = null;
    }
  }

  void _reframe() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => crHarbor(signal: widget.signal),
        ),
            (route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meterT.cancel();
    super.dispose();
  }

  // --- Утилиты ссылок (схемы/хосты) — переименованы, но логика сохранена ---
  bool _isNakedMail(Uri u) {
    final s = u.scheme;
    if (s.isNotEmpty) return false;
    final raw = u.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  Uri _mailize(Uri u) {
    final full = u.toString();
    final parts = full.split('?');
    final email = parts.first;
    final qp = parts.length > 1 ? Uri.splitQueryString(parts[1]) : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }



  bool _isPlatformish(Uri u) {
    final s = u.scheme.toLowerCase();
    if (_proto.contains(s)) return true;

    if (s == 'http' || s == 'https') {
      final h = u.host.toLowerCase();
      if (_dwell.contains(h)) return true;
      if (h.endsWith('t.me')) return true;
      if (h.endsWith('wa.me')) return true;
      if (h.endsWith('m.me')) return true;
      if (h.endsWith('signal.me')) return true;
    }
    return false;
  }

  Uri _httpize(Uri u) {
    final s = u.scheme.toLowerCase();

    if (s == 'tg' || s == 'telegram') {
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

    if ((s == 'http' || s == 'https') && u.host.toLowerCase().endsWith('t.me')) {
      return u;
    }

    if (s == 'viber') {
      return u;
    }

    if (s == 'whatsapp') {
      final qp = u.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${_digits(phone)}', {
          if (text != null && text.isNotEmpty) 'text': text,
        });
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if ((s == 'http' || s == 'https') &&
        (u.host.toLowerCase().endsWith('wa.me') || u.host.toLowerCase().endsWith('whatsapp.com'))) {
      return u;
    }

    if (s == 'skype') {
      return u;
    }

    if (s == 'fb-messenger') {
      final path = u.pathSegments.isNotEmpty ? u.pathSegments.join('/') : '';
      final qp = u.queryParameters;
      final id = qp['id'] ?? qp['user'] ?? path;
      if (id.isNotEmpty) {
        return Uri.https('m.me', '/$id', u.queryParameters.isEmpty ? null : u.queryParameters);
      }
      return Uri.https('m.me', '/', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if (s == 'sgnl') {
      final qp = u.queryParameters;
      final ph = qp['phone'];
      final un = qp['username'];
      if (ph != null && ph.isNotEmpty) {
        return Uri.https('signal.me', '/#p/${_digits(ph)}');
      }
      if (un != null && un.isNotEmpty) {
        return Uri.https('signal.me', '/#u/$un');
      }
      final path = u.pathSegments.join('/');
      if (path.isNotEmpty) {
        return Uri.https('signal.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
      }
      return u;
    }

    if (s == 'tel') {
      return Uri.parse('tel:${_digits(u.path)}');
    }

    if (s == 'mailto') {
      return u;
    }

    if (s == 'bnl') {
      final newPath = u.path.isNotEmpty ? u.path : '';
      return Uri.https('bnl.com', '/$newPath', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    return u;
  }

  Future<bool> _webMail(Uri mailto) async {
    final u = _gmailize(mailto);
    return await _webOpen(u);
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

  Future<bool> _webOpen(Uri u) async {
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

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
  String  ur="";

  var startload = 0;


  @override
  Widget build(BuildContext context) {
    // повторная привязка канала (как в исходнике)
    _bindNotifBridge();
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:  SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (_startCover)
              const LordsFluxLoader()
            else
              Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    InAppWebView(
                      key: ValueKey(_tick),
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
                        transparentBackground: true,
                      ),
                      initialUrlRequest: URLRequest(url: WebUri(_axis)),
                      onWebViewCreated: (c) {
                        _dock = c;

                        // MVP/MVVM после создания web-контроллера
                        _viewModel ??= hvViewModel(gizmo: _gear, skylark: _bird);
                        _present ??= hvPresenter(model: _viewModel!, webGetter: () => _dock);

                        _dock.addJavaScriptHandler(
                          handlerName: 'onServerResponse',
                          callback: (args) {
                            print("JS args: $args");
                            print("ResRes${args[0]['savedata']}");
                            if (args.isNotEmpty &&
                                args[0] is Map &&
                                args[0]['savedata'].toString() == "false") {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const sgAidLite()),
                                    (route) => false,
                              );
                            }
                            return args.reduce((curr, next) => curr + next);
                          },
                        );
                      },
                      onLoadStart: (c, u) async {

                        setState(() {
                          startload = DateTime.now().millisecondsSinceEpoch;
                        });
                        setState(() => _spin = true);
                        final v = u;
                        if (v != null) {
                          if (_isNakedMail(v)) {
                            try {
                              await c.stopLoading();
                            } catch (_) {}
                            final mailto = _mailize(v);
                            await _webMail(mailto);
                            return;
                          }
                          final sch = v.scheme.toLowerCase();
                          if (sch != 'http' && sch != 'https') {
                            try {
                              await c.stopLoading();
                            } catch (_) {}
                          }
                        }
                      },
                      // Ошибка загрузки главного документа
                      onLoadError: (controller, url, code, message) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "InAppWebViewError(code=$code, message=$message)";
                        await _postStat(
                          event: ev,
                          timeStart: now,
                          timefinsih: now,
                          url: url?.toString() ?? '',
                          appSid: _bird.mId, // <-- AFID
                          firstPageLoadTs: firstPageLoadTs,
                        );
                      },

                      // HTTP 4xx/5xx
                      onReceivedHttpError: (controller, request, errorResponse) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "HTTPError(status=${errorResponse.statusCode}, reason=${errorResponse.reasonPhrase})";
                        await _postStat(
                          event: ev,
                          timeStart: now,
                          timefinsih: now,
                          url: request.url?.toString() ?? '',
                          appSid: _bird.mId, // <-- AFID
                          firstPageLoadTs: firstPageLoadTs,
                        );
                      },

                      // Generic Android WebResourceError для отдельных ресурсов
                      onReceivedError: (controller, request, error) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final desc = (error.description ?? '').toString();
                        final ev = "WebResourceError(code=${error}, message=$desc)";
                        await _postStat(
                          event: ev,
                          timeStart: now,
                          timefinsih: now,
                          url: request.url?.toString() ?? '',
                          appSid: _bird.mId, // <-- AFID
                          firstPageLoadTs: firstPageLoadTs,
                        );
                      },

                      onLoadStop: (c, u) async {
                        await c.evaluateJavascript(source: "console.log('Harbor up!');");
                        print("Dock done $u");
                        await _sendGear();
                        await _sendWing();

                        setState(() {
                          ur=u.toString();
                        });

                        print("load ur "+ur.toString());
                        // Только один раз за установку
                        Future.delayed(const Duration(seconds: 20), (){
                      postLoadedOnce(
                            url: ur?.toString() ?? '',
                            timestart: startload,
                          );
                        });


                      },
                      shouldOverrideUrlLoading: (c, action) async {
                        final uri = action.request.url;
                        if (uri == null) return NavigationActionPolicy.ALLOW;

                        if (_isNakedMail(uri)) {
                          final mailto = _mailize(uri);
                          await _webMail(mailto);
                          return NavigationActionPolicy.CANCEL;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _webMail(uri);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (_isPlatformish(uri)) {
                          final web = _httpize(uri);
                          if (web.scheme == 'http' || web.scheme == 'https') {
                            await _webOpen(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri &&
                                  (web.scheme == 'http' || web.scheme == 'https')) {
                                await _webOpen(web);
                              }
                            } catch (_) {}
                          }
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch != 'http' && sch != 'https') {
                          return NavigationActionPolicy.CANCEL;
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (c, req) async {
                        final uri = req.request.url;
                        if (uri == null) return false;

                        if (_isNakedMail(uri)) {
                          final mailto = _mailize(uri);
                          await _webMail(mailto);
                          return false;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _webMail(uri);
                          return false;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return false;
                        }

                        if (_isPlatformish(uri)) {
                          final web = _httpize(uri);
                          if (web.scheme == 'http' || web.scheme == 'https') {
                            await _webOpen(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri &&
                                  (web.scheme == 'http' || web.scheme == 'https')) {
                                await _webOpen(web);
                              }
                            } catch (_) {}
                          }
                          return false;
                        }

                        if (sch == 'http' || sch == 'https') {
                          c.loadUrl(urlRequest: URLRequest(url: uri));
                        }
                        return false;
                      },
                      onDownloadStartRequest: (c, req) async {
                        await _webOpen(req.url);
                      },
                    ),
                    Visibility(
                      visible: !_veil,
                      child: const LordsFluxLoader(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Help-экраны (замена на новые названия и на новый лоудер)
// ============================================================================
class sgAid extends StatefulWidget {
  const sgAid({super.key});

  @override
  State<sgAid> createState() => _sgAidState();
}

class _sgAidState extends State<sgAid> with WidgetsBindingObserver {
  InAppWebViewController? _ctrl;
  bool _spin = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/index.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
              ),
              onWebViewCreated: (c) => _ctrl = c,
              onLoadStart: (c, u) => setState(() => _spin = true),
              onLoadStop: (c, u) async => setState(() => _spin = false),
              onLoadError: (c, u, code, msg) => setState(() => _spin = false),
            ),
            if (_spin) const LordsFluxLoader(),
          ],
        ),
      ),
    );
  }
}

class sgAidLite extends StatefulWidget {
  const sgAidLite({super.key});

  @override
  State<sgAidLite> createState() => _sgAidLiteState();
}

class _sgAidLiteState extends State<sgAidLite> {
  InAppWebViewController? _wvc;
  bool _ld = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/lords.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
                transparentBackground: true,
                mediaPlaybackRequiresUserGesture: false,
                disableDefaultErrorPage: true,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
              ),
              onWebViewCreated: (controller) {
                _wvc = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _ld = true;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  _ld = false;
                });
              },
              onLoadError: (controller, url, code, message) {
                setState(() {
                  _ld = false;
                });
              },
            ),
            if (_ld)
              const Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: LordsFluxLoader(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Точка входа
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  gxPrime();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(orionBgFcm);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  tz_data.initializeTimeZones();

  runApp(
    p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider(create: (_) => kxSkylark()),
      ],
      child: r.ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BlocProvider(
            create: (_) => rtWaveBloc(),
            child: const ztFoyer(),
          ),
        ),
      ),
    ),
  );
}