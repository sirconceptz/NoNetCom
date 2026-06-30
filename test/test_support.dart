import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Directory> prepareTestAppStorage(String prefix) async {
  SharedPreferences.setMockInitialValues({});
  final directory = Directory.systemTemp.createTempSync(prefix);
  PathProviderPlatform.instance = _TestPathProviderPlatform(directory.path);
  return directory;
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
