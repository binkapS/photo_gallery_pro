import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('PhotoGalleryException.fromCode', () {
    test('maps known codes to typed exceptions', () {
      expect(
        PhotoGalleryException.fromCode('PERMISSION_ERROR', 'no'),
        isA<PermissionDeniedException>(),
      );
      expect(
        PhotoGalleryException.fromCode('NOT_FOUND', 'no'),
        isA<NotFoundException>(),
      );
      expect(
        PhotoGalleryException.fromCode('INVALID_TYPE', 'no'),
        isA<UnsupportedMediaTypeException>(),
      );
      expect(
        PhotoGalleryException.fromCode('THUMBNAIL_ERROR', 'no'),
        isA<ThumbnailException>(),
      );
      expect(
        PhotoGalleryException.fromCode('ICLOUD_NOT_DOWNLOADED', 'no'),
        isA<CloudNotDownloadedException>(),
      );
      expect(
        PhotoGalleryException.fromCode('ALBUM_ERROR', 'no'),
        isA<NotFoundException>(),
      );
      expect(
        PhotoGalleryException.fromCode('FETCH_ERROR', 'no'),
        isA<PlatformGalleryException>(),
      );
    });

    test(
      'unknown codes map to PlatformGalleryException with the code kept',
      () {
        final PhotoGalleryException exception = PhotoGalleryException.fromCode(
          'SOME_NEW_CODE',
          'boom',
        );
        expect(exception, isA<PlatformGalleryException>());
        expect(exception.code, 'SOME_NEW_CODE');
        expect(exception.message, 'boom');
        expect(exception.toString(), contains('boom'));
      },
    );
  });

  group('MediaQuery', () {
    ImageMedia image({String name = 'photo.jpg'}) => ImageMedia(
      id: '1',
      name: name,
      uri: '1',
      dateAdded: DateTime(2025, 6, 1),
      size: 100,
      width: 4032,
      height: 3024,
      mimeType: 'image/jpeg',
    );

    test('nameContains is case-insensitive', () {
      const MediaQuery query = MediaQuery(nameContains: 'PHOTO');
      expect(query.matches(image()), isTrue);
      expect(query.matches(image(name: 'clip.mp4')), isFalse);
    });

    test('date bounds and dimensions filter', () {
      final MediaQuery query = MediaQuery(
        dateFrom: DateTime(2025, 1, 1),
        dateTo: DateTime(2025, 12, 31),
        minWidth: 4000,
        minHeight: 3000,
      );
      expect(query.matches(image()), isTrue);
      expect(query.matches(image().copyWith(width: 10)), isFalse);
    });

    test('mimeTypes requires a known matching mime', () {
      const MediaQuery query = MediaQuery(mimeTypes: <String>{'image/png'});
      expect(query.matches(image()), isFalse);
      final ImageMedia png = image().copyWith(mimeType: 'image/png');
      expect(query.matches(png), isTrue);
    });

    test('minDuration only matches videos', () {
      const MediaQuery query = MediaQuery(minDuration: Duration(seconds: 10));
      expect(query.matches(image()), isFalse);
    });

    test('empty query matches everything', () {
      const MediaQuery query = MediaQuery();
      expect(query.matches(image()), isTrue);
    });
  });
}
