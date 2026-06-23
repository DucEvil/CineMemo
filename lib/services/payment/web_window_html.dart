import 'dart:html' as html;

/// Opens a popup/tab on web and returns the window reference.
html.WindowBase? openWebWindow(String url) {
  return html.window.open(url, '_blank');
}

/// Returns true if the window is still open.
bool isWindowClosed(html.WindowBase? window) {
  return window == null || window.closed!;
}
