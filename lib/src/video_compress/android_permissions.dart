import 'package:permission_handler/permission_handler.dart';

/// For callers that explicitly need access to shared video storage.
/// App-private files and picker URI grants do not require this permission.
Future<bool> requestAndroidVideoPermission(int sdk) async {
  final permission = sdk >= 33 ? Permission.videos : Permission.storage;
  var status = await permission.status;
  if (status.isDenied) status = await permission.request();
  return status.isGranted || status.isLimited;
}
