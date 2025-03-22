import Flutter
import UIKit
import Photos
import PhotosUI

public class PhotoGalleryProPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "photo_gallery_pro", binaryMessenger: registrar.messenger())
        let instance = PhotoGalleryProPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAlbums":
            getAlbums(call, result: result)
        case "getMediaInAlbum":
            guard let args = call.arguments as? [String: Any],
                  let albumId = args["albumId"] as? String,
                  let mediaType = args["mediaType"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Album ID and media type required",
                                  details: nil))
                return
            }
            getMediaInAlbum(albumId: albumId, mediaType: mediaType, result: result)
        case "getThumbnail":
            guard let args = call.arguments as? [String: Any],
                  let mediaId = args["mediaId"] as? String,
                  let mediaType = args["mediaType"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                  message: "Media ID and type required",
                                  details: nil))
                return
            }
            getThumbnail(mediaId: mediaId, mediaType: mediaType, result: result)
        case "hasPermission":
            checkPermission(result: result)
        case "requestPermission":
            requestPermission(result: result)
        case "getAlbumThumbnail":
            checkAuthorization { authorized in 
                if authorized {
                    self.getAlbumThumbnail(call, result: result)
                } else {
                    result(FlutterError(
                        code: "PERMISSION_ERROR",
                        message: "Photo library access denied",
                        details: nil
                    ))
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getAlbums(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let mediaType = (call.arguments as? [String: Any])?["mediaType"] as? String
        
        let fetchOptions = PHFetchOptions()
        
        // Set media type filter if specified
        if let mediaType = mediaType {
            switch mediaType {
            case "image":
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            case "video":
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            default:
                result(FlutterError(code: "INVALID_TYPE", message: "Invalid media type: \(mediaType)", details: nil))
                return
            }
        }
        
        // Fetch user albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        
        // Fetch smart albums (Camera Roll, Videos, etc)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        var albums: [[String: Any]] = []
        
        // Process albums
        for collection in [userAlbums, smartAlbums] {
            collection.enumerateObjects { (album, _, _) in
                let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
                if assets.count > 0 {
                    // Determine album type based on first asset
                    let albumType = assets.firstObject?.mediaType == .video ? "video" : "image"
                    
                    albums.append([
                        "id": album.localIdentifier,
                        "name": album.localizedTitle ?? "Unknown",
                        "count": assets.count,
                        "type": albumType
                    ])
                }
            }
        }
        
        result.success(albums)
    }
    
    private func getMediaInAlbum(albumId: String, mediaType: String, result: @escaping FlutterResult) {
        let fetchOptions = PHFetchOptions()
        
        // Set predicate based on media type
        switch mediaType {
        case "image":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case "video":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        default:
            result(FlutterError(code: "INVALID_TYPE", message: "Invalid media type: \(mediaType)", details: nil))
            return
        }
        
        // Fetch assets in album
        guard let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId],
            options: nil
        ).firstObject else {
            result(FlutterError(code: "ALBUM_ERROR", message: "Album not found", details: nil))
            return
        }
        
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var mediaList: [[String: Any]] = []
        
        assets.enumerateObjects { (asset, index, _) in
            var mediaItem: [String: Any] = [
                "id": asset.localIdentifier,
                // Explicitly set the type based on the asset's mediaType
                "type": asset.mediaType == .image ? "image" : "video",
                "name": asset.originalFilename ?? "",
                "dateAdded": Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
                "width": asset.pixelWidth,
                "height": asset.pixelHeight,
                "size": asset.size
            ]
            
            // Add duration for video assets
            if asset.mediaType == .video {
                mediaItem["duration"] = Int(asset.duration * 1000) // Convert to milliseconds
            }
            
            mediaList.append(mediaItem)
        }
        
        result(mediaList)
    }
    
    private func getThumbnail(mediaId: String, mediaType: String, result: @escaping FlutterResult) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaId], options: nil).firstObject else {
            result(FlutterError(code: "INVALID_MEDIA", 
                              message: "Media not found", 
                              details: nil))
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 320, height: 320),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            guard let image = image else {
                result(FlutterError(code: "THUMBNAIL_ERROR",
                                  message: "Could not generate thumbnail",
                                  details: nil))
                return
            }
            
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                result(FlutterError(code: "COMPRESSION_ERROR",
                                  message: "Failed to compress image",
                                  details: nil))
                return
            }
            
            result(FlutterStandardTypedData(bytes: data))
        }
    }
    
    private func getAlbumThumbnail(albumId: String, mediaType: String, result: @escaping FlutterResult) {
        // Fetch the album by its local identifier.
        let fetchOptions = PHFetchOptions()
        let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: fetchOptions)
        guard let collection = collections.firstObject else {
            result(FlutterError(code: "ALBUM_ERROR", message: "Album not found: \(albumId)", details: nil))
            return
        }
        
        // Fetch assets in the album. You may add a predicate to filter by mediaType if needed.
        let assets = PHAsset.fetchAssets(in: collection, options: nil)
        guard assets.count > 0, let asset = assets.firstObject else {
            result(FlutterError(code: "ALBUM_THUMBNAIL_ERROR", message: "No assets found in album: \(albumId)", details: nil))
            return
        }
        
        // Request a thumbnail image from the asset.
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        let targetSize = CGSize(width: 320, height: 320)
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { (image, info) in
            guard let img = image, let data = img.jpegData(compressionQuality: 0.9) else {
                result(FlutterError(code: "ALBUM_THUMBNAIL_ERROR", message: "Could not generate album thumbnail.", details: nil))
                return
            }
            result(FlutterStandardTypedData(bytes: data))
        }
    }
    
    private func getAlbumThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let albumId = args["albumId"] as? String,
              let mediaType = args["mediaType"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Album ID and media type required",
                details: nil
            ))
            return
        }
        
        // Create fetch options
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // Filter based on media type
        switch mediaType {
        case "image":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case "video":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        default:
            result(FlutterError(
                code: "INVALID_TYPE",
                message: "Invalid media type: \(mediaType)",
                details: nil
            ))
            return
        }
        
        // Fetch the album
        guard let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId],
            options: nil
        ).firstObject else {
            result(FlutterError(
                code: "ALBUM_ERROR",
                message: "Album not found: \(albumId)",
                details: nil
            ))
            return
        }
        
        // Fetch assets in the album
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        guard let firstAsset = assets.firstObject else {
            result(FlutterError(
                code: "ALBUM_THUMBNAIL_ERROR",
                message: "No media found in album: \(albumId)",
                details: nil
            ))
            return
        }
        
        // Configure thumbnail request options
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        // Request thumbnail image
        PHImageManager.default().requestImage(
            for: firstAsset,
            targetSize: CGSize(width: 320, height: 320),
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            guard let image = image,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                result(FlutterError(
                    code: "THUMBNAIL_ERROR",
                    message: "Could not generate thumbnail",
                    details: nil
                ))
                return
            }
            
            // Return thumbnail data
            result(FlutterStandardTypedData(bytes: data))
        }
    }
    
    // Helper method to determine if asset is cached locally
    private func isAssetCached(_ asset: PHAsset) -> Bool {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return false }
        
        return resource.value(forKey: "fileSize") != nil
    }
    
    private func checkPermission(result: @escaping FlutterResult) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            result(true)
        default:
            result(false)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                result(status == .authorized || status == .limited)
            }
        }
    }
    
    private func checkAuthorization(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            completion(true)
        default:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        }
    }
}
