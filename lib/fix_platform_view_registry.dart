// ignore_for_file: avoid_web_libraries_in_flutter
// ignore_for_file: implementation_imports
// Fix for platformViewRegistry not being available in dart:ui

import 'dart:ui_web' as ui_web;

// Export the platformViewRegistry for web platform
final platformViewRegistry = ui_web.platformViewRegistry;