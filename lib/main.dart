import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:latlng/latlng.dart';
import 'package:map/map.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:ncmb/ncmb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

Future main() async {
  await dotenv.load(fileName: '.env');
  var applicationKey =
      dotenv.get('APPLICATION_KEY', fallback: 'No application key found.');
  var clientKey = dotenv.get('CLIENT_KEY', fallback: 'No client key found.');
  NCMB(applicationKey, clientKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final mapboxAccessToken = '';
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
      ),
      home: const MainPage(),
    );
  }
}

// 最初の画面用のStatefulWidget
class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // タイトル
  final title = '地図アプリ';

  // 表示するタブ
  final _tab = <Tab>[
    const Tab(text: '地図', icon: Icon(Icons.map_outlined)),
    const Tab(text: 'リスト', icon: Icon(Icons.list_outlined)),
  ];

  // AppBarとタブを表示
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tab.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: _tab,
          ),
        ),
        body: const TabBarView(children: [
          MapPage(),
          SettingPage(),
        ]),
      ),
    );
  }
}

// 地図画面用のStatefulWidget
class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);
  @override
  State<MapPage> createState() => _MapPageState();
}

// 地図画面
class _MapPageState extends State<MapPage> {
  // 地図コントローラーの初期化
  final controller = MapController(
    location: const LatLng(35.6585805, 139.7454329),
    zoom: 13,
  );
  // ドラッグ操作用
  Offset? _dragStart;
  double _scaleStart = 1.0;
  ScaleUpdateDetails? _details;

  // タップした位置の情報
  final List<LatLng> _clickLocations = [];
  // 表示するマーカー
  List<Widget> _markers = [];

  // 初期のスケール情報
  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = 1.0;
  }

  void _onScaleUpdate(MapTransformer transformer, ScaleUpdateDetails details) {
    final scaleDiff = details.scale - _scaleStart;
    _scaleStart = details.scale;
    if (scaleDiff > 0) {
      controller.zoom += 0.02;
    } else if (scaleDiff < 0) {
      controller.zoom -= 0.02;
      if (controller.zoom < 1) {
        controller.zoom = 1;
      }
    } else {
      final now = _details!.focalPoint;
      var diff = now - _dragStart!;
      _dragStart = now;
      final h = transformer.constraints.maxHeight;

      final vp = transformer.getViewport();
      if (diff.dy < 0 && vp.bottom - diff.dy < h) {
        diff = Offset(diff.dx, 0);
      }

      if (diff.dy > 0 && vp.top - diff.dy > 0) {
        diff = Offset(diff.dx, 0);
      }
      transformer.drag(diff.dx, diff.dy);
    }
    setState(() {});
  }

  // センターが変わったときの処理
  void _onScaleEnd(MapTransformer transformer, ScaleEndDetails details) {
    // マーカーを表示する
    showNotes(transformer);
  }

  // マーカーウィジェットを作成する
  Future<Widget> _buildMarkerWidget(
      NCMBObject note, MapTransformer transformer) async {
    final geo = note.get("geo") as NCMBGeoPoint;
    final pos = transformer.toOffset(LatLng(geo.latitude!, geo.longitude!));
    final image = await NCMBFile.download(note.getString("image"));
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      width: 40,
      height: 40,
      child: GestureDetector(
        child: SizedBox(
          child: Image.memory(image.data),
          height: 200,
        ),
        onTap: () {
          print("Tap");
        },
      ),
    );
  }

  Future<void> showNotes(MapTransformer transformer) async {
    final notes = await getNotes(transformer.controller.center);
    final markers = await Future.wait(notes.map((note) async {
      return await _buildMarkerWidget(note, transformer);
    }));
    print(markers);
    setState(() {
      _markers = markers;
    });
  }

  Future<List<NCMBObject>> getNotes(LatLng location) async {
    // NCMBGeoPointに変換
    var geo = NCMBGeoPoint(location.latitude, location.longitude);
    // 検索用のクエリークラス
    var query = NCMBQuery('Note');
    // 位置情報を中心に3km範囲で検索
    query.withinKilometers('geo', geo, 3);
    // レスポンスを取得
    var ary = await query.fetchAll();
    // List<NCMBObject>に変換
    return ary.map((obj) => obj as NCMBObject).toList();
  }

  // 地図をタップした際のイベント
  void _onTapUp(MapTransformer transformer, TapUpDetails details) async {
    // 地図上のXY
    final location = transformer.toLatLng(details.localPosition);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotePage(location: location)),
    );
  }

  double clamp(double x, double min, double max) {
    if (x < min) x = min;
    if (x > max) x = max;
    return x;
  }

  void _onDoubleTapDown(MapTransformer transformer, TapDownDetails details) {
    const delta = 0.5;
    final zoom = clamp(controller.zoom + delta, 2, 18);
    transformer.setZoomInPlace(zoom, details.localPosition);
    setState(() {});
  }

  void _onPointerSignal(MapTransformer transformer, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy / -1000.0;
    final zoom = clamp(controller.zoom + delta, 2, 18);
    transformer.setZoomInPlace(zoom, event.localPosition);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: MapLayout(
        controller: controller,
        builder: (context, transformer) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // タップした際のズーム処理
            onDoubleTapDown: (details) =>
                _onDoubleTapDown(transformer, details),
            // ピンチ/パン処理
            onScaleStart: _onScaleStart,
            onScaleUpdate: (details) => _onScaleUpdate(transformer, details),
            onScaleEnd: (details) => _onScaleEnd(transformer, details),
            // タップした際の処理
            onTapUp: (details) async {
              _onTapUp(transformer, details);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) => _onPointerSignal(transformer, event),
              child: Stack(
                  // Mapboxのウィジェットが初期化されているかどうかで処理分け
                  children: [
                    TileLayer(
                      builder: (context, x, y, z) {
                        final tilesInZoom = pow(2.0, z).floor();
                        while (x < 0) {
                          x += tilesInZoom;
                        }
                        while (y < 0) {
                          y += tilesInZoom;
                        }
                        x %= tilesInZoom;
                        y %= tilesInZoom;
                        return CachedNetworkImage(
                          imageUrl:
                              'https://tile.openstreetmap.org/$z/$x/$y.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                    ..._markers
                  ]),
            ),
          );
        },
      ),
    );
  }
}

class NotePage extends StatefulWidget {
  const NotePage({Key? key, this.location}) : super(key: key);
  final LatLng? location;

  @override
  State<NotePage> createState() => _NotePageState();
}

// 設定画面
class _NotePageState extends State<NotePage> {
  String? _address;
  String? _text;
  String? _extension;
  TextEditingController? _textEditingController;
  Uint8List? _image;
  final picker = ImagePicker();

  Future<void> _onPressed() async {
    final fileName = "${const Uuid().v4()}.$_extension";
    final geo =
        NCMBGeoPoint(widget.location!.latitude, widget.location!.longitude);
    final obj = NCMBObject('Note');
    obj.sets({'text': _text, 'address': _address, 'geo': geo});
    if (_image != null) {
      await NCMBFile.upload(fileName, _image);
      obj.set('image', fileName);
    }
    print(geo);
    await obj.save();
    Navigator.pop(context);
  }

  Future<void> _selectPhoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    var image = await pickedFile.readAsBytes();
    setState(() {
      _extension = pickedFile.mimeType!.split('/')[1];
      _image = image;
    });
  }

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    _getAddress();
  }

  Future<void> _getAddress() async {
    if (widget.location == null) return;
    final lat = widget.location!.latitude;
    final lng = widget.location!.longitude;
    final uri = Uri.parse(
        "https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?lat=$lat&lon=$lng");
    final response = await http.get(uri);
    final json = jsonDecode(response.body);
    final num = json['results']['muniCd'];
    String loadData = await rootBundle.loadString('csv/gsi.csv');
    final ary = loadData.split('\n');
    final line = ary.firstWhere((line) => line.split(',')[0] == num);
    final params = line.split(',');
    setState(() {
      _address = "${params[2]}${params[4]}${json['results']['lv01Nm']}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text(
              '写真を選択して、メモを入力してください',
            ),
            _image != null
                ? GestureDetector(
                    child: SizedBox(
                      child: Image.memory(_image!),
                      height: 200,
                    ),
                    onTap: _selectPhoto,
                  )
                : IconButton(
                    iconSize: 200,
                    icon: const Icon(
                      Icons.photo,
                      color: Colors.blue,
                    ),
                    onPressed: _selectPhoto,
                  ),
            Spacer(),
            _address != null
                ? Text(
                    "$_address付近のメモ",
                    style: const TextStyle(fontSize: 20),
                  )
                : const SizedBox(),
            const Spacer(),
            SizedBox(
              width: 300,
              child: TextFormField(
                controller: _textEditingController,
                enabled: true,
                style: const TextStyle(color: Colors.black),
                maxLines: 5,
                onChanged: (text) {
                  setState(() {
                    _text = text;
                  });
                },
              ),
            ),
            const Spacer(),
            ElevatedButton(onPressed: _onPressed, child: const Text('保存')),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// 設定画面用のStatefulWidget
class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  State<SettingPage> createState() => _SettingPageState();
}

// 設定画面
class _SettingPageState extends State<SettingPage> {
  final List<String> _logs = [];
  final String _className = 'Station';

  // データストアからすべての駅情報を削除
  Future<void> deleteAllStations() async {
    // 駅情報を検索するクエリークラス
    final query = NCMBQuery(_className);
    // 検索結果の取得件数
    query.limit(100);
    // 検索
    final ary = await query.fetchAll();
    // 順番に削除
    for (var station in ary) {
      station.delete();
    }
  }

  // 位置情報のJSONを取り込む処理
  Future<void> importGeoPoint() async {
    // ログを消す
    setState(() {
      _logs.clear();
    });
    // 全駅情報を消す
    deleteAllStations();
    // JSONファイルを読み込む
    String loadData = await rootBundle.loadString('json/yamanote.json');
    final stations = json.decode(loadData);
    // JSONファイルに従って処理
    stations.forEach((params) async {
      // 駅情報を作成
      var station = await saveStation(params);
      // ログを更新
      setState(() {
        _logs.add("${station.get('name')}を保存しました");
      });
    });
  }

  // 駅情報を作成する処理
  Future<NCMBObject> saveStation(params) async {
    // NCMBGeoPointを作成
    var geo = NCMBGeoPoint(
        double.parse(params['latitude']), double.parse(params['longitude']));
    // NCMBObjectを作成
    var station = NCMBObject(_className);
    // 位置情報、駅名をセット
    station
      ..set('name', params['name'])
      ..set('geo', geo);
    // 保存
    await station.save();
    return station;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '山手線のデータをインポートします',
        ),
        TextButton(onPressed: importGeoPoint, child: const Text('インポート')),
        Expanded(
          child: ListView.builder(
              itemBuilder: (BuildContext context, int index) =>
                  Text(_logs[index]),
              itemCount: _logs.length),
        )
      ],
    ));
  }
}
