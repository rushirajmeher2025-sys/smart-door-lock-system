import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../models/remote_command.dart';
import '../repositories/lock_repository.dart';
import '../services/firebase_init.dart';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri?.toString().contains('lock_action') == true) {
    await FirebaseInitService.initialize();
    final repo = lockRepository();
    await repo.sendCommand(RemoteAction.lock);
  }
}

class LockWidgetService {
  LockWidgetService._();
  static final LockWidgetService instance = LockWidgetService._();

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);
      await HomeWidget.setAppGroupId('group.com.smartlock.app.smart_door_lock');
    } catch (e) {
      debugPrint('[Widget] Init error: $e');
    }
  }

  Future<void> updateWidget({
    required String lockStatus,
    required String deviceName,
    required bool isOnline,
  }) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>('lock_status', lockStatus);
      await HomeWidget.saveWidgetData<String>('device_name', deviceName);
      await HomeWidget.saveWidgetData<bool>('is_online', isOnline);
      await HomeWidget.updateWidget(androidName: 'LockWidgetProvider');
    } catch (e) {
      debugPrint('[Widget] Update error: $e');
    }
  }
}
