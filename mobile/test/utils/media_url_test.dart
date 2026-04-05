import 'package:flutter_test/flutter_test.dart';
import 'package:periodically_notification/utils/media_url.dart';

void main() {
  group('MediaUrl.resolveForDevice', () {
    test(
      'removes misplaced motivasyon_gorselleri_pexels segment (MinIO flat key)',
      () {
        const wrong =
            'http://192.168.1.107:9000/motivationpictures/motivasyon_gorselleri_pexels/096_Vizyon.jpeg';
        expect(
          MediaUrl.resolveForDevice(wrong),
          'http://192.168.1.107:9000/motivationpictures/096_Vizyon.jpeg',
        );
      },
    );

    test('leaves already-correct path unchanged', () {
      const ok =
          'http://192.168.1.107:9000/motivationpictures/096_Vizyon.jpeg';
      expect(MediaUrl.resolveForDevice(ok), ok);
    });

    test('trims whitespace', () {
      const ok =
          'http://192.168.1.107:9000/motivationpictures/001_x.jpeg';
      expect(MediaUrl.resolveForDevice(' $ok '), ok);
    });
  });
}
