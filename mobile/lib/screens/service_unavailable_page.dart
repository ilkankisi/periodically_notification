import 'package:flutter/material.dart';

import '../services/reachability_service.dart';

/// İnternet veya backend yokken tam ekran; ana kabuk açılmadan önce gösterilir.
class ServiceUnavailablePage extends StatefulWidget {
  const ServiceUnavailablePage({
    super.key,
    required this.lastResult,
    required this.onRetry,
  });

  final ReachabilityResult lastResult;
  final Future<void> Function() onRetry;

  @override
  State<ServiceUnavailablePage> createState() => _ServiceUnavailablePageState();
}

class _ServiceUnavailablePageState extends State<ServiceUnavailablePage> {
  bool _busy = false;

  Future<void> _onRetry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNoNet = widget.lastResult.kind == ReachabilityKind.noConnection;
    final title = isNoNet ? 'İnternet bağlantısı yok' : 'Sunucuya ulaşılamıyor';
    final body = isNoNet
        ? 'Wi‑Fi veya mobil verinizi kontrol edin. Bağlantı olmadan uygulamayı kullanamazsınız.'
        : 'Sunucu yanıt vermiyor veya erişim engellendi. Bir süre sonra tekrar deneyin.';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                isNoNet ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
                size: 88,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF3F4F6),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2094F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Tekrar dene',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
