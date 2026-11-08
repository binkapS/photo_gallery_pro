import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('MediaTypeX.fromString', () {
    test('parses known types case-insensitively', () {
      expect(MediaTypeX.fromString('image'), MediaType.image);
      expect(MediaTypeX.fromString('VIDEO'), MediaType.video);
      expect(MediaTypeX.fromString('Mixed'), MediaType.mixed);
    });

    test('unknown types throw FormatException', () {
      expect(() => MediaTypeX.fromString('audio'), throwsFormatException);
      expect(() => MediaTypeX.fromString(''), throwsFormatException);
    });
  });

  group('PermissionStatusX', () {
    test('parses platform strings', () {
      expect(PermissionStatusX.fromString('granted'), PermissionStatus.granted);
      expect(
        PermissionStatusX.fromString('authorized'),
        PermissionStatus.granted,
      );
      expect(PermissionStatusX.fromString('limited'), PermissionStatus.limited);
      expect(PermissionStatusX.fromString('denied'), PermissionStatus.denied);
      expect(
        PermissionStatusX.fromString('restricted'),
        PermissionStatus.restricted,
      );
      expect(
        PermissionStatusX.fromString('notDetermined'),
        PermissionStatus.notDetermined,
      );
    });

    test('unknown status throws FormatException', () {
      expect(
        () => PermissionStatusX.fromString('maybe'),
        throwsFormatException,
      );
    });

    test('canReadMedia is true only for granted and limited', () {
      expect(PermissionStatus.granted.canReadMedia, isTrue);
      expect(PermissionStatus.limited.canReadMedia, isTrue);
      expect(PermissionStatus.denied.canReadMedia, isFalse);
      expect(PermissionStatus.notDetermined.canReadMedia, isFalse);
      expect(PermissionStatus.permanentlyDenied.canReadMedia, isFalse);
      expect(PermissionStatus.restricted.canReadMedia, isFalse);
    });
  });
}
