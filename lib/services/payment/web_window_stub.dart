/// Fallback stubs for non-web platforms.
Object? openWebWindow(String url) =>
    throw UnsupportedError('openWebWindow is only available on web');
bool isWindowClosed(Object? window) => true;
