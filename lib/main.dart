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
import 'package:flutter/painting.dart';
import 'package:geolocator/geolocator.dart';

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

  List<NCMBObject> _notes = [];
  LatLng _location = const LatLng(35.6585805, 139.7454329);

  void _setNotes(List<NCMBObject> notes) {
    setState(() {
      _notes = notes;
    });
  }

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
        body: TabBarView(children: [
          MapPage(setNotes: _setNotes, location: _location),
          ListPage(notes: _notes, location: _location),
        ]),
      ),
    );
  }
}

// 地図画面用のStatefulWidget
class MapPage extends StatefulWidget {
  const MapPage({Key? key, required this.setNotes, required this.location})
      : super(key: key);
  final Function(List<NCMBObject>) setNotes;
  final LatLng location;
  @override
  State<MapPage> createState() => _MapPageState();
}

// 地図画面
class _MapPageState extends State<MapPage> {
  // 地図コントローラーの初期化
  MapController? controller;
  // ドラッグ操作用
  Offset? _dragStart;
  double _scaleStart = 1.0;

  // 表示するマーカー
  List<Widget> _markers = [];
  Widget? _tooltip;

  @override
  void initState() {
    super.initState();
    controller = MapController(
      location: widget.location,
      zoom: 15,
    );
  }

  // 初期のスケール情報
  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = 1.0;
  }

  // センターが変わったときの処理
  void _onScaleUpdate(MapTransformer transformer, ScaleUpdateDetails details) {
    final scaleDiff = details.scale - _scaleStart;
    _scaleStart = details.scale;
    if (scaleDiff > 0) {
      controller!.zoom += 0.02;
      setState(() {});
    } else if (scaleDiff < 0) {
      controller!.zoom -= 0.02;
      if (controller!.zoom < 1) {
        controller!.zoom = 1;
      }
      setState(() {});
    } else {
      final now = details.focalPoint;
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
      setState(() {});
    }
  }

  void _onScaleEnd(MapTransformer transformer) {
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
        onTap: () => _onTap(pos.dy, pos.dx, note),
      ),
    );
  }

  Future<void> _onTap(double top, double left, NCMBObject note) async {
    final image = await NCMBFile.download(note.getString('image'));
    final tooltip = Container(
      margin: const EdgeInsets.only(left: 15.0),
      padding: const EdgeInsets.symmetric(
        vertical: 5.0,
        horizontal: 10.0,
      ),
      child: Column(children: [
        Text(note.getString('text')),
        Text(note.getString('address', defaultValue: "不明") + "付近のメモ"),
        SizedBox(
          child: Image.memory(image.data),
          height: 200,
        )
      ]),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: BubbleBorder(),
      ),
    );
    setState(() {
      _tooltip = Positioned(
        left: left - 170,
        top: top - 280,
        child: tooltip,
      );
    });
  }

  Future<void> showNotes(MapTransformer transformer) async {
    final notes = await getNotes(transformer.controller.center);
    final markers = await Future.wait(notes.map((note) async {
      return await _buildMarkerWidget(note, transformer);
    }));
    setState(() {
      widget.setNotes(notes);
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
    if (_tooltip != null) {
      setState(() {
        _tooltip = null;
      });
      return;
    }
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
    final zoom = clamp(controller!.zoom + delta, 2, 18);
    transformer.setZoomInPlace(zoom, details.localPosition);
    setState(() {});
  }

  void _onPointerSignal(MapTransformer transformer, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy / -1000.0;
    final zoom = clamp(controller!.zoom + delta, 2, 18);
    transformer.setZoomInPlace(zoom, event.localPosition);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: MapLayout(
        controller: controller!,
        builder: (context, transformer) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // タップした際のズーム処理
            onDoubleTapDown: (details) =>
                _onDoubleTapDown(transformer, details),
            // ピンチ/パン処理
            onScaleStart: _onScaleStart,
            onScaleUpdate: (details) => _onScaleUpdate(transformer, details),
            onScaleEnd: (details) => _onScaleEnd(transformer),
            // タップした際の処理
            onTapUp: (details) async {
              _onTapUp(transformer, details);
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) => _onPointerSignal(transformer, event),
              child: Stack(children: [
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
                      imageUrl: 'https://tile.openstreetmap.org/$z/$x/$y.png',
                      fit: BoxFit.cover,
                    );
                  },
                ),
                ..._markers,
                _tooltip != null ? _tooltip! : Container(),
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
class ListPage extends StatefulWidget {
  const ListPage({Key? key, required this.notes, required this.location})
      : super(key: key);
  final List<NCMBObject> notes;
  final LatLng location;

  @override
  State<ListPage> createState() => _ListPageState();
}

// 設定画面
class _ListPageState extends State<ListPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ListView.builder(
              itemBuilder: (BuildContext context, int index) =>
                  RowPage(note: widget.notes[index], location: widget.location),
              itemCount: widget.notes.length),
        )
      ],
    ));
  }
}

// 設定画面用のStatefulWidget
class RowPage extends StatefulWidget {
  const RowPage({Key? key, required this.note, required this.location})
      : super(key: key);
  final NCMBObject note;
  final LatLng location;
  @override
  State<RowPage> createState() => _RowPageState();
}

// 設定画面
class _RowPageState extends State<RowPage> {
  Uint8List? _image;

  @override
  void initState() {
    super.initState();
    _getImage();
  }

  Future<void> _getImage() async {
    if (widget.note.get('image') == null) return;
    final fileName = widget.note.getString('image');
    final image = await NCMBFile.download(fileName);
    setState(() {
      _image = image.data;
    });
  }

  String distance() {
    final geo = widget.note.get('geo') as NCMBGeoPoint;
    final dist = Geolocator.distanceBetween(widget.location.latitude,
        widget.location.longitude, geo.latitude!, geo.longitude!);
    return dist.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _image != null
          ? SizedBox(
              child: Image.memory(_image!),
              width: 150,
            )
          : const SizedBox(
              child: Icon(
              Icons.photo,
              size: 100,
              color: Colors.grey,
            )),
      const Padding(padding: EdgeInsets.only(left: 8)),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.note.getString('text')),
        Text(widget.note.getString('address', defaultValue: '不明')),
        Text('${distance()}m')
      ])
    ]);
  }
}

class BubbleBorder extends ShapeBorder {
  final bool usePadding;

  const BubbleBorder({this.usePadding = true});

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.only(bottom: usePadding ? 12 : 0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r =
        Rect.fromPoints(rect.topLeft, rect.bottomRight - const Offset(0, 12));
    return Path()
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)))
      ..moveTo(r.bottomCenter.dx - 10, r.bottomCenter.dy)
      ..relativeLineTo(10, 12)
      ..relativeLineTo(10, -12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
