import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  /// Creates the demo app.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Gallery Pro Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  /// Creates the demo home page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PhotoGalleryPro _gallery = PhotoGalleryPro();
  final ThumbnailCache _cache = ThumbnailCache(
    maxEntries: 500,
    maxBytes: 20 << 20,
  );

  List<Album> _albums = [];
  Album? _selectedAlbum;
  List<Media> _mediaFiles = [];
  MediaType _filter = MediaType.mixed;
  PermissionStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initGallery();
  }

  Future<void> _initGallery() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Platform.isLinux) {
        PermissionStatus status = await _gallery.getPermissionStatus();
        if (status == PermissionStatus.notDetermined) {
          status = await _gallery.requestPermission();
        }
        setState(() => _status = status);
        if (!status.canReadMedia) {
          setState(() {
            _error = 'Gallery permission denied';
            _loading = false;
          });
          return;
        }
      } else {
        setState(() => _status = PermissionStatus.granted);
      }
      await _loadAlbums();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAlbums() async {
    final List<Album> albums = await _gallery.getAlbums(type: _filter);
    setState(() {
      _albums = albums;
      _loading = false;
    });
  }

  Future<void> _loadAlbumMedia(Album album) async {
    setState(() {
      _loading = true;
      _selectedAlbum = album;
    });
    try {
      final List<Media> mediaFiles = await _gallery.getMediaInAlbum(
        album.id,
        type: MediaType.mixed,
        sort: MediaSort.dateAddedDesc,
      );
      setState(() {
        _mediaFiles = mediaFiles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goBack() {
    setState(() {
      _selectedAlbum = null;
      _mediaFiles = [];
      _loading = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_selectedAlbum?.name ?? 'Photo Gallery Pro Demo'),
        leading:
            _selectedAlbum != null
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
                : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(
        message: _error!,
        action: ElevatedButton(
          onPressed: _initGallery,
          child: const Text('Retry'),
        ),
      );
    }
    return _selectedAlbum == null ? _buildAlbumView() : _buildMediaView();
  }

  Widget _buildMessage({required String message, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumView() {
    return Column(
      children: [
        if (_status == PermissionStatus.limited)
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Limited photo access'),
            subtitle: Text('Only selected media is visible'),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _chip('All', MediaType.mixed),
              _chip('Photos', MediaType.image),
              _chip('Videos', MediaType.video),
            ],
          ),
        ),
        Expanded(
          child:
              _albums.isEmpty
                  ? _buildMessage(message: 'No albums found')
                  : RefreshIndicator(
                    onRefresh: _loadAlbums,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _albums.length,
                      itemBuilder: (context, index) {
                        final Album album = _albums[index];
                        return InkWell(
                          onTap: () => _loadAlbumMedia(album),
                          child: AlbumThumb(
                            album: album,
                            gallery: _gallery,
                            cache: _cache,
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _chip(String label, MediaType type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == type,
        onSelected: (_) {
          setState(() => _filter = type);
          _loadAlbums();
        },
      ),
    );
  }

  Widget _buildMediaView() {
    if (_mediaFiles.isEmpty) {
      return _buildMessage(message: 'This album is empty');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _mediaFiles.length,
      itemBuilder: (context, index) {
        final Media media = _mediaFiles[index];
        return MediaThumb(
          media: media,
          gallery: _gallery,
          cache: _cache,
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => PhotoViewer(
                        media: media,
                        gallery: _gallery,
                        cache: _cache,
                      ),
                ),
              ),
        );
      },
    );
  }
}

/// Album tile that fetches its thumbnail exactly once (in [initState]) and
/// serves repeats from the shared [ThumbnailCache].
class AlbumThumb extends StatefulWidget {
  /// Creates an [AlbumThumb].
  const AlbumThumb({
    super.key,
    required this.album,
    required this.gallery,
    required this.cache,
  });

  /// The album whose thumbnail is shown.
  final Album album;

  /// The gallery facade used to load the thumbnail.
  final PhotoGalleryPro gallery;

  /// The shared thumbnail cache.
  final ThumbnailCache cache;

  @override
  State<AlbumThumb> createState() => _AlbumThumbState();
}

class _AlbumThumbState extends State<AlbumThumb> {
  Future<Thumbnail>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache.getOrLoad(
      'album:${widget.album.id}',
      () => widget.gallery.getAlbumThumbnail(
        widget.album.id,
        type: widget.album.type,
        size: const ThumbnailSize.square(320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Thumbnail>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Icon(
                    widget.album.type == MediaType.video
                        ? Icons.video_library
                        : Icons.photo_library,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Hero(
                tag: 'album_${widget.album.id}',
                child: Image.memory(
                  snapshot.data!.data,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  cacheHeight: 320,
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha((.5 * 255).toInt()),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.album.count} items',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Media cell that fetches its thumbnail exactly once and caches it.
class MediaThumb extends StatefulWidget {
  /// Creates a [MediaThumb].
  const MediaThumb({
    super.key,
    required this.media,
    required this.gallery,
    required this.cache,
    this.onTap,
  });

  /// The media item shown in this cell.
  final Media media;

  /// The gallery facade used to load the thumbnail.
  final PhotoGalleryPro gallery;

  /// The shared thumbnail cache.
  final ThumbnailCache cache;

  /// Called when the cell is tapped.
  final VoidCallback? onTap;

  @override
  State<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<MediaThumb> {
  Future<Thumbnail>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache.getOrLoad(
      widget.media.id,
      () => widget.gallery.getThumbnail(
        widget.media.id,
        size: const ThumbnailSize.square(320),
        type: widget.media.type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Thumbnail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.error_outline));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InkWell(
          onTap: widget.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'media_${widget.media.id}',
                child: Image.memory(
                  snapshot.data!.data,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  cacheHeight: 320,
                ),
              ),
              if (widget.media is VideoMedia)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(Icons.play_circle_fill, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Detail screen showing the media's metadata fields (uri, filePath, size,
/// duration, mimeType) — proving the new fields are wired end to end.
class PhotoViewer extends StatelessWidget {
  /// Creates a [PhotoViewer].
  const PhotoViewer({
    super.key,
    required this.media,
    required this.gallery,
    required this.cache,
  });

  /// The media item displayed.
  final Media media;

  /// The gallery facade (kept for future byte-loading features).
  final PhotoGalleryPro gallery;

  /// The shared thumbnail cache.
  final ThumbnailCache cache;

  @override
  Widget build(BuildContext context) {
    final VideoMedia? video = media is VideoMedia ? media as VideoMedia : null;
    return Scaffold(
      appBar: AppBar(title: Text(media.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: FutureBuilder<Thumbnail>(
              future: cache.getOrLoad(
                media.id,
                () => gallery.getThumbnail(
                  media.id,
                  size: const ThumbnailSize.square(1024),
                ),
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.memory(snapshot.data!.data, fit: BoxFit.contain);
              },
            ),
          ),
          const SizedBox(height: 16),
          _row('URI', media.uri),
          _row('Path', media.filePath ?? '(cloud / not locally cached)'),
          _row('Type', media.type.name),
          _row('MIME', media.mimeType ?? '(unknown)'),
          _row('Size', '${media.size} bytes'),
          _row('Dimensions', '${media.width}×${media.height}'),
          if (video != null) _row('Duration', video.duration.toString()),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
