## 0.0.5

* Fixed Linux platform support:
  * Fixed method channel error handling
  * Corrected thumbnail generation using GDK-Pixbuf
  * Fixed media type parameter handling
  * Improved error messages for better debugging
  * Added proper null checks for method arguments
  * Fixed directory traversal in album listing
  * Improved memory management for thumbnails
  * Added proper cleanup of GObject resources

## 0.0.4

* Added ability to filter albums by media type (image/video)
* Fixed image thumbnail generation on Android
* Added proper error handling for thumbnail generation
* Improved album thumbnail loading with loading states
* Enhanced example app UI with Material Design 3
* Added proper error states and loading indicators
* Fixed media type detection in thumbnail generation
* Added documentation for new features
* Added Linux platform support:
  * Album browsing and filtering
  * Thumbnail generation using GDK-Pixbuf
  * Media browsing within albums
  * Direct file system access via Pictures directory

## 0.0.3

* Added album thumbnail support
* Improved error handling and debug logging
* Updated platform implementations for better stability
* Enhanced example app with visual feedback
* Added proper resource cleanup in platform code
* Fixed video thumbnail generation on Android
* Updated documentation with new examples
* Added support for video thumbnails on iOS and Android
* Improved error handling
* Fixed album sorting issues

## 0.0.2

* Fixed media type detection in Media.fromJson
* Added basic thumbnail support
* Implemented permission handling
* Added example implementation
* Initial iOS support
* Initial Android support
* Added support for:
  * Album filtering by media type
  * Album thumbnails
  * Media thumbnails
  * Permission handling
* Improved documentation
* Added example app

## 0.0.1

* Initial release
* Basic album and media fetching
* Permission handling
* Platform interface definition
* Basic functionality:
  * List albums
  * Get media in albums
  * Basic permission handling
