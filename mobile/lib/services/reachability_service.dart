import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Son kontrolün özeti (tam ekran mesajı için).
enum ReachabilityKind {
  ok,
  noConnection,
  serverUnreachable,
}

class ReachabilityResult {
  const ReachabilityResult(this.kind);

  final ReachabilityKind kind;

  bool get isOk => kind == ReachabilityKind.ok;
}

/// Ağ arayüzü + `GET /api/health` ile backend erişilebilirliği.
class ReachabilityService {
  ReachabilityService._();

  static const Duration _healthTimeout = Duration(seconds: 8);

  static Future<ReachabilityResult> check() async {
    if (kDebugMode) {
      ApiConfig.debugLogResolvedUrl();
    }

    final connectivity = Connectivity();
    List<ConnectivityResult> statuses;
    try {
      statuses = await connectivity.checkConnectivity();
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Reachability] connectivity check failed: $e');
        debugPrint('$st');
      }
      return const ReachabilityResult(ReachabilityKind.noConnection);
    }

    final hasLink = statuses.any((s) => s != ConnectivityResult.none);
    if (!hasLink) {
      if (kDebugMode) {
        debugPrint('[Reachability] no link (connectivity: $statuses)');
      }
      return const ReachabilityResult(ReachabilityKind.noConnection);
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/health');
    if (kDebugMode) {
      debugPrint('[Reachability] GET $uri');
    }

    try {
      final r = await http.get(uri).timeout(_healthTimeout);
      if (kDebugMode) {
        debugPrint('[Reachability] health → ${r.statusCode}');
      }
      if (r.statusCode != 200) {
        return const ReachabilityResult(ReachabilityKind.serverUnreachable);
      }
      try {
        final m = jsonDecode(r.body) as Map<String, dynamic>?;
        final status = m?['status'] as String?;
        if (status == 'ok') {
          return const ReachabilityResult(ReachabilityKind.ok);
        }
      } on Object catch (_) {}
      return const ReachabilityResult(ReachabilityKind.serverUnreachable);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[Reachability] health timeout');
      }
      return const ReachabilityResult(ReachabilityKind.serverUnreachable);
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Reachability] health error: $e');
        debugPrint('$st');
      }
      return const ReachabilityResult(ReachabilityKind.serverUnreachable);
    }
  }
}
