import 'package:flutter/foundation.dart';

void logDebug(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

