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
      theme: ThemeData(primarySwatch: Colors.blue),
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
      // Check and request permissions
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

      // Get all albums
      final albums = await _photoGallery.getAlbums();
      setState(() {
        _albums = albums;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAlbumMedia(String albumId) async {
    setState(() => _loading = true);
    try {
      final mediaFiles = await _photoGallery.getMediaInAlbum(
        albumId,
        type: MediaType.image,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Gallery Pro Demo')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _mediaFiles.isEmpty
              ? _buildAlbumList()
              : _buildMediaGrid(),
    );
  }

  Widget _buildAlbumList() {
    return ListView.builder(
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return ListTile(
          title: Text(album.name),
          subtitle: Text('${album.photoCount} items'),
          onTap: () => _loadAlbumMedia(album.id),
        );
      },
    );
  }

  Widget _buildMediaGrid() {
    return Stack(
      children: [
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: _mediaFiles.length,
          itemBuilder: (context, index) {
            final media = _mediaFiles[index];
            return FutureBuilder<Thumbnail>(
              future: _photoGallery.getThumbnail(
                media.id,
                type: MediaType.image,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.file(
                    File(snapshot.data!.imageUrl),
                    fit: BoxFit.cover,
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            );
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: FloatingActionButton(
            mini: true,
            child: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _mediaFiles = []);
            },
          ),
        ),
      ],
    );
  }
}
