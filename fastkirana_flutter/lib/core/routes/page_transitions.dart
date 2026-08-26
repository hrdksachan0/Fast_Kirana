import 'package:flutter/material.dart';

/// Premium MaterialPageRoute used app-wide for 100% stable page routing across Web & Mobile.
class FadeSlideRoute<T> extends MaterialPageRoute<T> {
  final Widget page;

  FadeSlideRoute({required this.page, super.settings})
      : super(builder: (context) => page);
}
