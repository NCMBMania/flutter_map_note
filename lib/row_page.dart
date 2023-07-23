import 'package:flutter/material.dart';
import 'package:latlng/latlng.dart';
import 'package:ncmb/ncmb.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';

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
