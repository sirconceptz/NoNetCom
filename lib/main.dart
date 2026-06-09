import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'src/app/chat_shell.dart';
part 'src/app/app_dependencies.dart';
part 'src/app/app_lifecycle_coordinator.dart';
part 'src/app/controllers/contacts_controller.dart';
part 'src/app/controllers/diagnostics_controller.dart';
part 'src/app/controllers/file_transfer_controller.dart';
part 'src/app/controllers/lifecycle_controller.dart';
part 'src/app/controllers/message_controller.dart';
part 'src/app/controllers/security_controller.dart';
part 'src/app/controllers/transport_controller.dart';
part 'src/app/controllers/voice_controller.dart';
part 'src/app/controllers/live_voice_controller.dart';
part 'src/ui/common/common_widgets.dart';
part 'src/ui/common/status_tile.dart';
part 'src/ui/onboarding/onboarding_pane.dart';
part 'src/ui/contacts/contacts_pane.dart';
part 'src/ui/chat/chat_pane.dart';
part 'src/ui/chat/live_voice_panel.dart';
part 'src/data/store.dart';
part 'src/services/security.dart';
part 'src/services/app_info.dart';
part 'src/services/error_log.dart';
part 'src/services/diagnostics.dart';
part 'src/services/diagnostics_report.dart';
part 'src/services/notifications.dart';
part 'src/services/voice.dart';
part 'src/services/crypto.dart';
part 'src/transport/reliable_transport.dart';
part 'src/platform/platform_bridges.dart';
part 'src/domain/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppErrorLog.instance.load();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AppErrorLog.instance.logFlutter(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      AppErrorLog.instance.logError(
        error,
        stack,
        source: 'platform_dispatcher',
      ),
    );
    return true;
  };
  runZonedGuarded(
    () => runApp(const OfflineChatApp()),
    (error, stack) => unawaited(
      AppErrorLog.instance.logError(error, stack, source: 'dart_zone'),
    ),
  );
}

const _serviceName = 'NoNetCom';
const _emojiChoices = ['👍', '❤️', '😂', '🔥', '🙏', '🎉', '👋', '✅'];
const _framePayloadSize = 128;
const _fileChunkBytes = 12 * 1024;
const _maxFileBytes = 30 * 1024 * 1024;
const _maxSendAttempts = 5;
const _maxGroupMembers = 6;
const _maxVoiceMessageBytes = 5 * 1024 * 1024;
const _maxVoiceMessageDuration = Duration(seconds: 45);
const _liveVoiceSegmentDuration = Duration(milliseconds: 900);
const _maxLiveVoicePendingSegments = 4;
const _developerLogEmail = 'kontakt@mapapps.tech';
