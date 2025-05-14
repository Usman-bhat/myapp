import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class ScanResult {
  final String url;
  final int? statusCode;
  final int? contentLength;
  final String? error;
  final bool isHit;

  ScanResult({
    required this.url,
    this.statusCode,
    this.contentLength,
    this.error,
    required this.isHit,
  });
}

Future<List<ScanResult>> performScanIsolate(Map<String, dynamic> data) async {
  final baseUrl = data['baseUrl'] as String;
  final wordlistChunk = data['wordlistChunk'] as List<String>;
  final includeStatusCodes = data['includeStatusCodes'] as List<int>;
  final excludeStatusCodes = data['excludeStatusCodes'] as List<int>;
  final extensions = data['extensions'] as List<String>;
  final ignoreSsl = data['ignoreSsl'] as bool;

  final dio = Dio();

  // Configure SSL settings
  if (ignoreSsl) {
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    };
  }

  List<ScanResult> results = [];

  for (String word in wordlistChunk) {
    final path = word.trim();
    if (path.isEmpty) continue;

    // Check for extensions
    List<String> urlsToTest = [path];
    if (extensions.isNotEmpty) {
      urlsToTest.addAll(extensions.map((ext) => '$path$ext'));
    }

    for (String urlPath in urlsToTest) {
      final url = '$baseUrl/$urlPath';

      try {
        final response = await dio.get(url);
        if (includeStatusCodes.contains(response.statusCode) &&
            !excludeStatusCodes.contains(response.statusCode)) {
          results.add(
            ScanResult(
              url: url,
              statusCode: response.statusCode,
              contentLength: response.data.toString().length,
              isHit: true,
            ),
          );
        }
      } on DioException catch (e) {
        results.add(ScanResult(url: url, error: e.message, isHit: false));
      } catch (e) {
        results.add(ScanResult(url: url, error: e.toString(), isHit: false));
      }
    }
  }

  return results;
}

Future<List<String>> readWordlist(String filePath) async {
  try {
    if (filePath.startsWith('assets/')) {
      String content = await rootBundle.loadString(filePath);
      return content.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    } else {
      final file = File(filePath);
      List<String> lines = await file.readAsLines();
      return lines.map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    }
  } catch (e) {
    print("Error reading wordlist: $e");
    return [];
  }
}

Future<List<ScanResult>> startBruteforce(
  String baseUrl,
  List<String> wordlist, {
  int numberOfThreads = 5,
  List<int> includeStatusCodes = const [],
  List<int> excludeStatusCodes = const [],
  List<String> extensions = const [],
  bool ignoreSsl = false,
}) async {
  if (wordlist.isEmpty) return [];
  int chunkSize = (wordlist.length / numberOfThreads).ceil();
  List<List<String>> chunks = [];

  for (int i = 0; i < wordlist.length; i += chunkSize) {
    chunks.add(
      wordlist.sublist(
        i,
        i + chunkSize > wordlist.length ? wordlist.length : i + chunkSize,
      ),
    );
  }

  List<Future<List<ScanResult>>> futures = chunks.map((chunk) {
    return compute(performScanIsolate, {
      'baseUrl': baseUrl,
      'wordlistChunk': chunk,
      'includeStatusCodes': includeStatusCodes, // Corrected key
      'excludeStatusCodes': excludeStatusCodes,
      'extensions': extensions,
      'ignoreSsl': ignoreSsl,
    });
  }).toList();

  final results = await Future.wait(futures);
  return results.expand((list) => list).toList();
}

