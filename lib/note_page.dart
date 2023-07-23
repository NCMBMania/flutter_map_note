import 'package:flutter/material.dart';
import 'package:latlng/latlng.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:ncmb/ncmb.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

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
