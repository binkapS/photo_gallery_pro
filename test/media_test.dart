import 'package:flutter_test/flutter_test.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  group('Media.fromJson', () {
    test('image media parses all fields', () {
      final Media media = Media.fromJson(<String, dynamic>{
        'id': '10',
        'name': 'photo.jpg',
        'uri': 'content://media/external/images/media/10',
        'type': 'image',
        'dateAdded': 1_700_000_000,
        'size': 2048,
        'width': 4032,
        'height': 3024,
        'mimeType': 'image/jpeg',
      });

      expect(media, isA<ImageMedia>());
      expect(media.id, '10');
      expect(media.name, 'photo.jpg');
      expect(media.filename, 'photo.jpg');
      expect(media.created, media.dateAdded);
      expect(media.uri, 'content://media/external/images/media/10');
      expect(
        media.dateAdded,
        DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      );
      expect(media.size, 2048);
      expect(media.width, 4032);
      expect(media.height, 3024);
      expect(media.mimeType, 'image/jpeg');
      expect(media.filePath, isNull);
    });

    test('video media parses duration', () {
      final Media media = Media.fromJson(<String, dynamic>{
        'id': '11',
        'name': 'clip.mp4',
        'uri': '11',
        'type': 'video',
        'dateAdded': 1_700_000_000,
        'duration': 90_000,
        'size': 51_200,
        'width': 1920,
        'height': 1080,
      });

      expect(media, isA<VideoMedia>());
      expect(
        (media as VideoMedia).duration,
        const Duration(milliseconds: 90_000),
      );
    });

    test('video with missing duration defaults to zero', () {
      final Media media = Media.fromJson(<String, dynamic>{
        'id': '11',
        'name': 'clip.mp4',
        'type': 'video',
      });
      expect((media as VideoMedia).duration, Duration.zero);
    });

    test('unknown type throws FormatException', () {
      expect(
        () => Media.fromJson(<String, dynamic>{'id': '1', 'type': 'auditory'}),
        throwsFormatException,
      );
    });

    test('legacy path payload falls back to filePath', () {
      final Media media = Media.fromJson(<String, dynamic>{
        'id': '1',
        'name': 'a.jpg',
        'type': 'image',
        'path': '/storage/emulated/0/Pictures/a.jpg',
      });
      expect(media.filePath, '/storage/emulated/0/Pictures/a.jpg');
    });

    test('round-trips through toJson/fromJson', () {
      final Media original = Media.fromJson(<String, dynamic>{
        'id': '10',
        'name': 'photo.jpg',
        'uri': '10',
        'type': 'image',
        'dateAdded': 1_700_000_000,
        'size': 100,
        'width': 50,
        'height': 60,
        'mimeType': 'image/jpeg',
        'filePath': '/pics/photo.jpg',
      });
      expect(Media.fromJson(original.toJson()), original);
    });

    test('image and video with same id are not equal', () {
      final Media image = Media.fromJson(<String, dynamic>{
        'id': '1',
        'type': 'image',
      });
      final Media video = Media.fromJson(<String, dynamic>{
        'id': '1',
        'type': 'video',
      });
      expect(image, isNot(video));
    });
  });
}
