import 'package:flutter/material.dart';
import 'package:ncmb/ncmb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './main_page.dart';

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
