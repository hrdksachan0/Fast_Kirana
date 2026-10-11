import 'dart:async';

import 'package:flutter/material.dart';

/// Every autoplay owner observes both the app lifecycle and its route/tab.
abstract class NavratriAutoplayState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  final List<Timer> _timers = [];
  bool _running = false;
  bool get manuallyPaused => false;
  bool get reducedMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  bool get autoplayAllowed =>
      !manuallyPaused &&
      !reducedMotion &&
      TickerMode.valuesOf(context).enabled &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void startTimers();

  void periodic(Duration interval, VoidCallback callback) {
    _timers.add(Timer.periodic(interval, (_) {
      if (mounted && autoplayAllowed) callback();
    }));
  }

  void syncAutoplay({bool force = false}) {
    final shouldRun = autoplayAllowed;
    if (!force && shouldRun == _running) return;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _running = shouldRun;
    if (shouldRun) startTimers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncAutoplay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => syncAutoplay();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// Outgoing slides retain their pixels during the crossfade, never semantics,
/// focus or pointer targets. The current slide owns the layout and hit area.
Widget navratriSwitcherLayout(Widget? current, List<Widget> outgoing) => Stack(
      alignment: Alignment.center,
      children: [
        for (final child in outgoing)
          Positioned.fill(
            child: ExcludeSemantics(
              child: ExcludeFocus(
                child: IgnorePointer(child: child),
              ),
            ),
          ),
        if (current != null) current,
      ],
    );
