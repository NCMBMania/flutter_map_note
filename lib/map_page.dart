import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:latlng/latlng.dart';
import 'package:map/map.dart';
import 'package:ncmb/ncmb.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import './bubble_border.dart';
import './note_page.dart';

// 地図画面用のStatefulWidget
class MapPage extends StatefulWidget {
  const MapPage({Key? key, required this.setNotes, required this.location})
      : super(key: key);
  final Function(List<dynamic>) setNotes;
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
    final pos = transformer.toOffset(widget.location);
    final image = NCMBFile();
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

  Future<void> _onTap(double top, double left, NCMBObject note) async {}

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
    return [];
  }

  // 地図をタップした際のイベント
  void _onTapUp(MapTransformer transformer, TapUpDetails details) async {
    // ツールチップが表示されている場合は非表示にして終了
    if (_tooltip != null) {
      setState(() {
        _tooltip = null;
      });
      return;
    }
    // 地図上のXY
    final location = transformer.toLatLng(details.localPosition);
    // メモ追加画面を表示
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
