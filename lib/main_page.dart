import 'package:flutter/material.dart';
import 'package:latlng/latlng.dart';
import './map_page.dart';
import './list_page.dart';

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

  List<dynamic> _notes = [];
  // List<NCMBObject> _notes = [];
  final LatLng _location = const LatLng(35.6585805, 139.7454329);

  void _setNotes(List<dynamic> notes) {
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
