import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_gallery_pro/photo_gallery_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
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
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _photoGallery = PhotoGalleryPro();
  List<Album> _albums = [];
  Album? _selectedAlbum;
  List<Media> _mediaFiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initGallery();
  }

  Future<void> _initGallery() async {
    try {
      // On Linux, we don't need permission checks
      if (!Platform.isLinux) {
        if (!await _photoGallery.hasPermission()) {
          final granted = await _photoGallery.requestPermission();
          if (!granted) {
            setState(() {
              _error = 'Permission denied';
              _loading = false;
            });
            return;
          }
        }
      }

      // Add debug print to track album loading
      print('Loading albums...');
      final albums = await _photoGallery.getAlbums();
      print('Loaded ${albums.length} albums');

      setState(() {
        _albums = albums;
        _loading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading albums: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAlbumMedia(Album album) async {
    setState(() {
      _loading = true;
      _selectedAlbum = album;
    });

    try {
      final mediaFiles = await _photoGallery.getMediaInAlbum(
        album.id,
        type: album.type,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initGallery,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return _selectedAlbum == null ? _buildAlbumGrid() : _buildMediaGrid();
  }

  Widget _buildAlbumGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return InkWell(
          onTap: () => _loadAlbumMedia(album),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Thumbnail>(
                  future: _photoGallery.getAlbumThumbnail(
                    album.id,
                    type: album.type,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint(
                        'Failed to load album thumbnail: ${snapshot.error}',
                      );
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              album.type == MediaType.image
                                  ? Icons.photo_library
                                  : Icons.video_library,
                              size: 48,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading thumbnail',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Icon(
                            album.type == MediaType.image
                                ? Icons.photo_library
                                : Icons.video_library,
                            size: 48,
                            color: Colors.grey.withAlpha((.5 * 255).toInt()),
                          ),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }

                    return Hero(
                      tag: 'album_${album.id}',
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
                          album.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${album.count} items',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid() {
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
        final media = _mediaFiles[index];
        return FutureBuilder<Thumbnail>(
          future: _photoGallery.getThumbnail(media.id, type: media.type),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              // debugPrint(media.type.toString());
              debugPrint('Failed to load thumbnail: ${snapshot.error}');
              return const Center(child: Icon(Icons.error));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return InkWell(
              onTap: () {
                debugPrint('media path: ${media.path}');
                // Handle media tap (e.g., open in a new screen)
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'media_${media.id}',
                    child: Image.memory(
                      snapshot.data!.data,
                      fit: BoxFit.cover,
                      cacheWidth: 320, // Optimize memory usage
                      cacheHeight: 320,
                    ),
                  ),
                  if (media is VideoMedia)
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
      },
    );
  }
}
