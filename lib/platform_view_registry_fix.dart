// ignore_for_file: avoid_web_libraries_in_flutter, depend_on_referenced_packages
// Platform-specific fix for web compilation issues

import 'dart:ui_web' as ui_web;
// ignore: unused_import
import 'package:web/web.dart' as web;

// Export the platformViewRegistry for web platform
final platformViewRegistry = ui_web.platformViewRegistry;
