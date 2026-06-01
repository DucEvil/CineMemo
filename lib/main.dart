import 'package:flutter/widgets.dart';
import 'bootstrap/app_bootstrap.dart';
import 'app.dart';

Future<void> main() async {
  final bootstrap = await AppBootstrap.initialize();
  runApp(CineMemoRootApp(bootstrap: bootstrap));
}
