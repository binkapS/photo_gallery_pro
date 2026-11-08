import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('Album', () {
    test('round-trips through toJson/fromJson', () {
      const Album album = Album(
        id: '42',
        name: 'Camera Roll',
        count: 12,
        type: MediaType.mixed,
        thumbnailMediaId: '7',
        path: '/pics',
        lastModified: null,
      );

      expect(Album.fromJson(album.toJson()), album);
    });

    test('parses mixed type', () {
      final Album album = Album.fromJson(<String, dynamic>{
        'id': '1',
        'name': 'A',
        'count': 3,
        'type': 'mixed',
      });
      expect(album.type, MediaType.mixed);
    });

    test('unknown type throws FormatException', () {
      expect(
        () => Album.fromJson(<String, dynamic>{
          'id': '1',
          'name': 'A',
          'count': 1,
          'type': 'hovercraft',
        }),
        throwsFormatException,
      );
    });

    test('defaults count to 0 and type stays mixed when omitted', () {
      final Album album = Album.fromJson(<String, dynamic>{'id': '1'});
      expect(album.count, 0);
      expect(album.name, '');
      expect(album.type, MediaType.mixed);
    });

    test('parses isSmart flag and round-trips it', () {
      final Album album = Album.fromJson(<String, dynamic>{
        'id': '1',
        'name': 'Camera Roll',
        'type': 'mixed',
        'isSmart': true,
      });
      expect(album.isSmart, isTrue);
      expect(Album.fromJson(album.toJson()).isSmart, isTrue);
      expect(Album.fromJson(<String, dynamic>{'id': '1'}).isSmart, isFalse);
    });

    test('value equality and copyWith', () {
      const Album a = Album(
        id: '1',
        name: 'A',
        count: 1,
        type: MediaType.image,
      );
      const Album b = Album(
        id: '1',
        name: 'A',
        count: 1,
        type: MediaType.image,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(count: 2).count, 2);
      expect(a.copyWith(count: 2), isNot(a));
    });
  });
}
