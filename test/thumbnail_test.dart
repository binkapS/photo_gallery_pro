import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('Thumbnail.fromPlatformData', () {
    test('bare Uint8List parses with defaults', () {
      final Thumbnail thumb = Thumbnail.fromPlatformData(
        Uint8List.fromList(<int>[1, 2, 3]),
      );
      expect(thumb.data, <int>[1, 2, 3]);
      expect(thumb.width, 512);
      expect(thumb.height, 512);
      expect(thumb.format, ThumbnailFormat.jpeg);
    });

    test('canonical map parses width/height/format', () {
      final Thumbnail thumb = Thumbnail.fromPlatformData(<String, dynamic>{
        'data': Uint8List.fromList(<int>[1, 2]),
        'width': 100,
        'height': 200,
        'format': 'png',
      });
      expect(thumb.width, 100);
      expect(thumb.height, 200);
      expect(thumb.format, ThumbnailFormat.png);
    });

    test('legacy bytes key parses', () {
      final Thumbnail thumb = Thumbnail.fromPlatformData(<String, dynamic>{
        'bytes': Uint8List.fromList(<int>[9]),
      });
      expect(thumb.data, <int>[9]);
    });

    test('empty data throws FormatException', () {
      expect(
        () =>
            Thumbnail.fromPlatformData(<String, dynamic>{'data': Uint8List(0)}),
        throwsFormatException,
      );
    });

    test('missing data throws FormatException', () {
      expect(
        () => Thumbnail.fromPlatformData(<String, dynamic>{'width': 10}),
        throwsFormatException,
      );
    });

    test('invalid payload type throws FormatException', () {
      expect(
        () => Thumbnail.fromPlatformData('not-a-thumb'),
        throwsFormatException,
      );
    });

    test('value equality compares bytes, not identity', () {
      final Thumbnail a = Thumbnail(data: Uint8List.fromList(<int>[1, 2]));
      final Thumbnail b = Thumbnail(data: Uint8List.fromList(<int>[1, 2]));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(identical(b, a)));
    });

    test('different bytes are not equal', () {
      final Thumbnail a = Thumbnail(data: Uint8List.fromList(<int>[1]));
      final Thumbnail b = Thumbnail(data: Uint8List.fromList(<int>[2]));
      expect(a, isNot(b));
    });

    test('round-trips through toJson/fromJson', () {
      final Thumbnail thumb = Thumbnail(
        data: Uint8List.fromList(<int>[1, 2]),
        width: 64,
        height: 64,
        format: ThumbnailFormat.png,
      );
      expect(Thumbnail.fromPlatformData(thumb.toJson()), thumb);
    });
  });
}
