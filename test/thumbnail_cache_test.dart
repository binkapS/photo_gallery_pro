import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('ThumbnailCache', () {
    test('getOrLoad loads once and then serves from cache', () async {
      final ThumbnailCache cache = ThumbnailCache();
      var calls = 0;
      Future<Thumbnail> loader() async {
        calls++;
        return Thumbnail(data: Uint8List.fromList(<int>[calls]));
      }

      expect((await cache.getOrLoad('a', loader)).data, <int>[1]);
      expect((await cache.getOrLoad('a', loader)).data, <int>[1]);
      expect(calls, 1);
      expect(cache.length, 1);
      expect(cache.contains('a'), isTrue);
    });

    test('evicts least-recently-used entries by count', () async {
      final ThumbnailCache cache = ThumbnailCache(
        maxEntries: 2,
        maxBytes: 1 << 20,
      );
      Future<Thumbnail> loader() async => Thumbnail(data: Uint8List(1));

      await cache.getOrLoad('a', loader);
      await cache.getOrLoad('b', loader);
      await cache.getOrLoad('a', loader); // touch a -> b is LRU
      await cache.getOrLoad('c', loader);

      expect(cache.contains('a'), isTrue);
      expect(cache.contains('b'), isFalse);
      expect(cache.contains('c'), isTrue);
      expect(cache.length, 2);
    });

    test('evicts by byte budget', () async {
      final ThumbnailCache cache = ThumbnailCache(
        maxEntries: 100,
        maxBytes: 10,
      );
      Future<Thumbnail> loader(int bytes) async =>
          Thumbnail(data: Uint8List(bytes));

      await cache.getOrLoad('a', () => loader(8));
      await cache.getOrLoad('b', () => loader(8)); // 16 > 10 -> evict 'a'

      expect(cache.contains('b'), isTrue);
      expect(cache.contains('a'), isFalse);
      expect(cache.bytes, 8);
    });

    test('concurrent getOrLoad for same id loads once', () async {
      final ThumbnailCache cache = ThumbnailCache();
      var calls = 0;
      Future<Thumbnail> loader() async {
        calls++;
        await Future<void>.delayed(Duration.zero);
        return Thumbnail(data: Uint8List.fromList(<int>[7]));
      }

      final List<Thumbnail> results = await Future.wait(<Future<Thumbnail>>[
        cache.getOrLoad('x', loader),
        cache.getOrLoad('x', loader),
        cache.getOrLoad('x', loader),
      ]);
      expect(calls, 1);
      for (final Thumbnail r in results) {
        expect(r.data, <int>[7]);
      }
    });

    test('clear empties the cache', () async {
      final ThumbnailCache cache = ThumbnailCache();
      Future<Thumbnail> loader() async => Thumbnail(data: Uint8List(1));
      await cache.getOrLoad('a', loader);
      cache.clear();
      expect(cache.length, 0);
      expect(cache.bytes, 0);
      expect(cache.contains('a'), isFalse);
    });
  });
}
