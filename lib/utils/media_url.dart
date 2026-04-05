import 'package:flutter/foundation.dart';

/// Fiziksel cihazda sunucunun ürettiği `127.0.0.1` / `localhost` tabanlı görseller
/// (ör. `http://127.0.0.1:9001/api/v1/download-shared-object/...`) açılmaz.
///
/// [API_BASE_URL] içindeki **host** ile loopback host değiştirilir; **port, path ve sorgu**
/// aynı kalır (9001 ağ geçidi ile 9000 doğrudan MinIO ayrımı korunur).
///
/// **AWS/MinIO imzalı URL** (`X-Amz-*` sorgu parametreleri): Host imzaya bağlıdır;
/// loopback’ten IP’ye çevirmek 403 imza hatası verir — bu durumda URL olduğu gibi
/// bırakılır; görünür URL’yi backend telefonun erişeceği host ile üretmelidir.
///
/// İsteğe bağlı: API farklı makinede, medya başka IP’deyse
/// `--dart-define=PUBLIC_MEDIA_BASE_URL=http://192.168.x.x` — yalnızca host alınır.
class MediaUrl {
  MediaUrl._();

  static const String _publicMediaBase = String.fromEnvironment(
    'PUBLIC_MEDIA_BASE_URL',
    defaultValue: '',
  );

  static const String _apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String _replacementHost() {
    final media = _publicMediaBase.trim();
    if (media.isNotEmpty) {
      var s = media;
      if (s.endsWith('/')) s = s.substring(0, s.length - 1);
      final u = Uri.tryParse(s);
      if (u != null && u.host.isNotEmpty) return u.host;
    }
    final u = Uri.tryParse(_apiBase.trim());
    return u?.host ?? '';
  }

  static bool _isLoopbackHost(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  /// S3/MinIO ön imzalı isteklerde host imzaya dâhildir; burada değiştirilemez.
  static bool _isAwsStyleSignedQuery(Uri u) {
    for (final key in u.queryParameters.keys) {
      if (key.toLowerCase().startsWith('x-amz-')) return true;
    }
    return false;
  }

  /// [downloadedFile] yolu bazen yanlışlıkla `imageUrl` içine ekleniyor; bucket'ta düz
  /// anahtar varken (`motivationpictures/096_...`) bu ara segment 404 verir.
  static Uri _stripMisplacedPexelsFolder(Uri u) {
    const seg = 'motivasyon_gorselleri_pexels/';
    if (!u.path.contains(seg)) return u;
    final newPath = u.path.replaceAll(seg, '');
    return Uri(
      scheme: u.scheme.isEmpty ? 'http' : u.scheme,
      userInfo: u.userInfo.isEmpty ? null : u.userInfo,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: newPath,
      query: u.query.isEmpty ? null : u.query,
      fragment: u.fragment.isEmpty ? null : u.fragment,
    );
  }

  /// Sunucunun döndürdüğü veya cache'teki URL'yi cihazın görebileceği hosta çevirir.
  static String? resolveForDevice(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    var parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;

    parsed = _stripMisplacedPexelsFolder(parsed);

    if (!_isLoopbackHost(parsed.host)) {
      return parsed.toString();
    }

    if (_isAwsStyleSignedQuery(parsed)) {
      if (kDebugMode) {
        debugPrint(
          'MediaUrl: imzalı URL loopback host ile; host değiştirilmedi. '
          'Backend imageUrl üretirken LAN/public taban kullanmalı (ör. MINIO_PUBLIC_URL).',
        );
      }
      return parsed.toString();
    }

    final newHost = _replacementHost();
    if (newHost.isEmpty || _isLoopbackHost(newHost)) {
      return parsed.toString();
    }

    return Uri(
      scheme: parsed.scheme.isEmpty ? 'http' : parsed.scheme,
      userInfo: parsed.userInfo.isEmpty ? null : parsed.userInfo,
      host: newHost,
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path,
      query: parsed.query.isEmpty ? null : parsed.query,
      fragment: parsed.fragment.isEmpty ? null : parsed.fragment,
    ).toString();
  }
}
