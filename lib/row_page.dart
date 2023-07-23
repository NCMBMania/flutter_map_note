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
  }

  String distance() {
    return "";
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
      Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('${distance()}m')])
    ]);
  }
}
