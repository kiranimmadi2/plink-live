// ignore_for_file: avoid_web_libraries_in_flutter
// Platform-specific fix for web compilation issues
library platform_view_registry_fix;

import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// Export the platformViewRegistry for web platform
final platformViewRegistry = ui_web.platformViewRegistry;

// This is a workaround to fix the compilation issue with agora_rtc_engine on web
void registerPlatformViewFactory(String viewType, html.Element Function(int viewId) viewFactory) {
  // This is just a stub for web compilation
}