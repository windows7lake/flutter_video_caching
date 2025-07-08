import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class HttpClientCustomPage extends StatefulWidget {
  const HttpClientCustomPage({super.key});

  @override
  State<HttpClientCustomPage> createState() => _HttpClientCustomPageState();
}

class _HttpClientCustomPageState extends State<HttpClientCustomPage> {
  String _result = 'Waiting for test...';
  bool _isLoading = false;

  // Test valid certificate verification
  Future<void> _testValidCertificate() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing valid certificate verification...';
    });

    try {
      final client = HttpClient();
      HttpClientRequest request =
          await client.getUrl(Uri.parse('https://www.google.com'));
      HttpClientResponse response = await request.close();

      setState(() {
        _result = 'Valid certificate verification succeeded\n'
            'Status code: ${response.statusCode}\n'
            'Content length: ${response.contentLength}';
      });
    } catch (e) {
      setState(() {
        _result = 'Valid certificate verification failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test self-signed certificate verification (with callback)
  Future<void> _testSelfSignedCertificate() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing self-signed certificate verification...';
    });

    try {
      // Create custom HttpClient, configure badCertificateCallback
      final client = HttpClientCustom().create();

      // Note: Here we use httpbin.org's self-signed certificate test endpoint
      HttpClientRequest request =
          await client.getUrl(Uri.parse('https://self-signed.badssl.com'));
      HttpClientResponse response = await request.close();

      setState(() {
        _result =
            'Self-signed certificate verification succeeded (with callback)\n'
            'Status code: ${response.statusCode}\n'
            'Content length: ${response.contentLength}';
      });
    } catch (e) {
      setState(() {
        _result = 'Self-signed certificate verification failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test self-signed certificate verification (without callback)
  Future<void> _testSelfSignedCertificateWithoutCallback() async {
    setState(() {
      _isLoading = true;
      _result =
          'Testing self-signed certificate verification without callback...';
    });

    try {
      final client = HttpClientDefault().create();
      // This will fail because badCertificateCallback is not configured
      HttpClientRequest request =
          await client.getUrl(Uri.parse('https://self-signed.badssl.com'));
      HttpClientResponse response = await request.close();

      setState(() {
        _result =
            'Self-signed certificate verification succeeded without callback (unexpected!)\n'
            'Status code: ${response.statusCode}\n'
            'Content length: ${response.contentLength}';
      });
    } catch (e) {
      setState(() {
        _result =
            'Self-signed certificate verification failed without callback (expected): $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Verification Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testValidCertificate,
              child: const Text(
                'Test valid certificate verification',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed:
                  _isLoading ? null : _testSelfSignedCertificateWithoutCallback,
              child: const Text(
                'Test self-signed certificate verification'
                '\n (without callback)',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _testSelfSignedCertificate,
              child: const Text(
                'Test self-signed certificate verification'
                '\n (with callback)',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test result:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: SingleChildScrollView(
                    child: Text(_result),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
