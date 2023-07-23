import 'package:flutter/material.dart';
import 'package:latlng/latlng.dart';
import 'package:ncmb/ncmb.dart';
import './row_page.dart';

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
