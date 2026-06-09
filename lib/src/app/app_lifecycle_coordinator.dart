part of '../../main.dart';

typedef AppLifecycleCallback = Future<void> Function(AppLifecycleState state);

class AppLifecycleCoordinator with WidgetsBindingObserver {
  AppLifecycleCoordinator(this.onStateChanged);

  final AppLifecycleCallback onStateChanged;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(onStateChanged(state));
  }
}
