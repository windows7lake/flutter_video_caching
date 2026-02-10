# Migration from v0.4.x to v1.0.0

## 1.0.0 Release Notes
**Breaking Changed**
- refactor: remove `isolate` to simplify the code and improve performance
- refactor: adjust the task schedule logic to ensure high-priority tasks are executed first, improving responsiveness
- feat: use dio as the default http client for better performance and reliability
- feat: restarting the proxy server after an interruption
- fix: handle socket exception during download to prevent crashes and improve stability

## Migration Guide

### Custom HttpClient
**Before**:
```dart
class HttpClientCustom extends HttpClientBuilder {
  @override
  HttpClient create() {
    return HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Print certificate info for debugging
        debugPrint('Certificate subject: ${cert.subject}');
        debugPrint('Issuer: ${cert.issuer}');
        debugPrint('Valid until: ${cert.endValidity}');
        debugPrint('SHA-1 fingerprint: ${cert.sha1}');

        // Custom verification logic: here simply allow all certificates, should be stricter in real applications
        // For example, verify if the certificate fingerprint matches the expected value
        return true;
      };
  }
}
```
**After**:
```dart
class HttpClientCustom extends HttpClientBuilder {
  @override
  Dio create() {
    Dio dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client =
      HttpClient(context: SecurityContext(withTrustedRoots: false));
      // You can test the intermediate / root cert here. We just ignore it.
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        // Print certificate info for debugging
        debugPrint('Certificate subject: ${cert.subject}');
        debugPrint('Issuer: ${cert.issuer}');
        debugPrint('Valid until: ${cert.endValidity}');
        debugPrint('SHA-1 fingerprint: ${cert.sha1}');

        // Custom verification logic: here simply allow all certificates, should be stricter in real applications
        // For example, verify if the certificate fingerprint matches the expected value
        return true;
      };
      return client;
    });
    return dio;
  }
}
```

### DownloadManager Api changed

```dart
DownloadManager downloadManager = DownloadManager();

// Before
downloadManager.activeTasks
// After
downloadManager.downloadingTasks

// Before
downloadManager.roundIsolate();
// After
downloadManager.roundTask();

// Before
downloadManager.isUrlExit(url);
// After
downloadManager.isTaskExit(task);

// Before
downloadManager.removeAllTask();
// After
downloadManager.cancelAllTask();

// Remove
downloadManager.poolSize
downloadManager.isolateSize

// New
downloadManager.pauseTaskAboutUrl(url);
downloadManager.cancelTaskAboutUrl(url);
```