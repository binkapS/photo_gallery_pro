import Flutter
import UIKit
import Photos
import UniformTypeIdentifiers

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
            getMediaInAlbum(call, result: result)
        case "getThumbnail":
            getThumbnail(call, result: result)
        case "getAlbumThumbnail":
            getAlbumThumbnail(call, result: result)
        case "getThumbnailBatch":
            getThumbnailBatch(call, result: result)
        case "getOriginalBytes":
            getOriginalBytes(call, result: result)
        case "getPermissionStatus":
            result(permissionStatusString(PHPhotoLibrary.authorizationStatus(for: .readWrite)))
        case "hasPermission":
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            result(status == .authorized || status == .limited)
        case "requestPermission":
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    result(self.permissionStatusString(status))
                }
            }
        case "getPlatformVersion":
            result("iOS \(UIDevice.current.systemVersion)")
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission helpers

    private func permissionStatusString(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "granted"
        case .limited:
            return "limited"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "denied"
        }
    }

    private var hasReadPermission: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private func permissionError() -> FlutterError {
        return FlutterError(code: "PERMISSION_ERROR", message: "Photo library access denied", details: nil)
    }

    // MARK: - Argument helpers

    private func optionalInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func targetSize(from args: [String: Any]) -> (width: Int, height: Int) {
        let width = optionalInt(args["width"]) ?? 320
        let height = optionalInt(args["height"]) ?? width
        return (width, height)
    }

    private func thumbnailFormat(from args: [String: Any]) -> String {
        let raw = (args["format"] as? String)?.lowercased() ?? "jpeg"
        return raw == "png" ? "png" : "jpeg"
    }

    // MARK: - Shared thumbnail helper (Single source of thumbnail logic)

    /// Requests a scaled thumbnail for an asset. Calls `completion` exactly once.
    private func requestThumbnailData(
        asset: PHAsset,
        targetWidth: Int,
        targetHeight: Int,
        format: String,
        completion: @escaping (Data?, Int, Int, String) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: targetWidth, height: targetHeight),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            let effectiveFormat = format == "png" ? "png" : "jpeg"
            guard let image = image else {
                completion(nil, targetWidth, targetHeight, effectiveFormat)
                return
            }
            if effectiveFormat == "png" {
                completion(image.pngData(), targetWidth, targetHeight, effectiveFormat)
            } else {
                completion(image.jpegData(compressionQuality: 0.9), targetWidth, targetHeight, effectiveFormat)
            }
        }
    }

    private func thumbnailMap(data: Data, width: Int, height: Int, format: String) -> [String: Any] {
        return [
            "data": FlutterStandardTypedData(bytes: data),
            "width": width,
            "height": height,
            "format": format,
        ]
    }

    // MARK: - getAlbums

    private func getAlbums(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }

        let args = (call.arguments as? [String: Any]) ?? [:]
        let mediaTypeRaw = args["mediaType"] as? String
        if let mediaTypeRaw = mediaTypeRaw {
            switch mediaTypeRaw {
            case "image", "video", "mixed":
                break
            default:
                result(FlutterError(code: "INVALID_TYPE", message: "Invalid media type: \(mediaTypeRaw)", details: nil))
                return
            }
        }
        let offset = optionalInt(args["offset"]) ?? 0
        let limit = optionalInt(args["limit"])

        var albums: [[String: Any]] = []

        let albumCollections = [
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil),
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil),
        ]

        for collections in albumCollections {
            collections.enumerateObjects { album, _, _ in
                guard album.assetCollectionSubtype != .any else { return }

                let assetFetchOptions = PHFetchOptions()
                assetFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let albumAssets = PHAsset.fetchAssets(in: album, options: assetFetchOptions)

                var imageCount = 0
                var videoCount = 0
                albumAssets.enumerateObjects { asset, _, _ in
                    if asset.mediaType == .image {
                        imageCount += 1
                    } else if asset.mediaType == .video {
                        videoCount += 1
                    }
                }

                let total = imageCount + videoCount
                guard total > 0 else { return }

                if let filter = mediaTypeRaw {
                    if filter == "image" && imageCount == 0 { return }
                    if filter == "video" && videoCount == 0 { return }
                }

                let albumType: String
                if imageCount > 0 && videoCount > 0 {
                    albumType = "mixed"
                } else if videoCount > 0 {
                    albumType = "video"
                } else {
                    albumType = "image"
                }

                var thumbnailAsset: PHAsset?
                for candidate in albumAssets {
                    if let filter = mediaTypeRaw {
                        if filter == "image" && candidate.mediaType != .image { continue }
                        if filter == "video" && candidate.mediaType != .video { continue }
                    }
                    thumbnailAsset = candidate
                    break
                }

                var entry: [String: Any] = [
                    "id": album.localIdentifier,
                    "name": album.localizedTitle ?? "Unknown",
                    "count": total,
                    "type": albumType,
                ]
                if let thumb = thumbnailAsset {
                    entry["thumbnailMediaId"] = thumb.localIdentifier
                    entry["lastModified"] = Int(thumb.creationDate?.timeIntervalSince1970 ?? 0)
                }
                albums.append(entry)
            }
        }

        let start = max(0, offset)
        let boundedStart = min(start, albums.count)
        let boundedEnd = limit.map { min(albums.count, boundedStart + max(0, $0)) } ?? albums.count
        result(Array(albums[boundedStart..<boundedEnd]))
    }

    // MARK: - getMediaInAlbum

    private func getMediaInAlbum(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }

        guard let args = call.arguments as? [String: Any],
              let albumId = args["albumId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Album ID required", details: nil))
            return
        }
        let mediaTypeRaw = (args["mediaType"] as? String) ?? "mixed"
        switch mediaTypeRaw {
        case "image", "video", "mixed":
            break
        default:
            result(FlutterError(code: "INVALID_TYPE", message: "Invalid media type: \(mediaTypeRaw)", details: nil))
            return
        }

        guard let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId], options: nil
        ).firstObject else {
            result(FlutterError(code: "NOT_FOUND", message: "Album not found: \(albumId)", details: nil))
            return
        }

        let fetchOptions = PHFetchOptions()
        switch mediaTypeRaw {
        case "image":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case "video":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        default:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        }

        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)

        var mediaList: [[String: Any]] = []
        assets.enumerateObjects { asset, _, _ in
            // Build metadata only; never read image data synchronously.
            let resources = PHAssetResource.assetResources(for: asset)
            let firstResource = resources.first
            let name = firstResource?.originalFilename ?? ""
            let mimeType: String
            if let first = firstResource {
                let ext = (first.originalFilename as NSString).pathExtension
                mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? ""
            } else {
                mimeType = ""
            }
            let size: Int
            if let first = firstResource, let fileSize = first.value(forKey: "fileSize") as? NSNumber {
                size = fileSize.intValue
            } else {
                size = 0
            }
            let dateAdded = Int(asset.creationDate?.timeIntervalSince1970 ?? 0)
            let dateModified = Int(asset.modificationDate?.timeIntervalSince1970 ?? asset.creationDate?.timeIntervalSince1970 ?? 0)
            var media: [String: Any] = [
                "id": asset.localIdentifier,
                "uri": asset.localIdentifier,
                "name": name,
                "mimeType": mimeType,
                "type": asset.mediaType == .video ? "video" : "image",
                "dateAdded": dateAdded,
                "dateModified": dateModified,
                "size": size,
                "width": asset.pixelWidth,
                "height": asset.pixelHeight,
            ]
            if asset.mediaType == .video {
                media["duration"] = Int(asset.duration.seconds * 1000)
            }
            // filePath is intentionally omitted; uri is the lookup key.
            mediaList.append(media)
        }

        let sortRaw = (args["sort"] as? String) ?? "dateAddedDesc"
        switch sortRaw {
        case "dateAddedAsc":
            mediaList.sort { ($0["dateAdded"] as? Int ?? 0) < ($1["dateAdded"] as? Int ?? 0) }
        case "nameAsc":
            mediaList.sort { (($0["name"] as? String) ?? "") < (($1["name"] as? String) ?? "") }
        case "sizeDesc":
            mediaList.sort { ($0["size"] as? Int ?? 0) > ($1["size"] as? Int ?? 0) }
        default:
            mediaList.sort { ($0["dateAdded"] as? Int ?? 0) > ($1["dateAdded"] as? Int ?? 0) }
        }

        let offset = optionalInt(args["offset"]) ?? 0
        let limit = optionalInt(args["limit"])
        let start = max(0, offset)
        let boundedStart = min(start, mediaList.count)
        let boundedEnd = limit.map { min(mediaList.count, boundedStart + max(0, $0)) } ?? mediaList.count
        result(Array(mediaList[boundedStart..<boundedEnd]))
    }

    // MARK: - getThumbnail

    private func getThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }
        guard let args = call.arguments as? [String: Any],
              let mediaId = args["mediaId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Media ID required", details: nil))
            return
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaId], options: nil).firstObject else {
            result(FlutterError(code: "NOT_FOUND", message: "Media not found: \(mediaId)", details: nil))
            return
        }
        let size = targetSize(from: args)
        let format = thumbnailFormat(from: args)
        requestThumbnailData(asset: asset, targetWidth: size.width, targetHeight: size.height, format: format) { data, width, height, effectiveFormat in
            if let data = data {
                let payload = self.thumbnailMap(data: data, width: width, height: height, format: effectiveFormat)
                DispatchQueue.main.async { result(payload) }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_ERROR", message: "Could not generate thumbnail", details: nil))
                }
            }
        }
    }

    // MARK: - getAlbumThumbnail

    private func getAlbumThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }
        guard let args = call.arguments as? [String: Any],
              let albumId = args["albumId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Album ID required", details: nil))
            return
        }
        let mediaTypeRaw = (args["mediaType"] as? String) ?? "mixed"
        switch mediaTypeRaw {
        case "image", "video", "mixed":
            break
        default:
            result(FlutterError(code: "INVALID_TYPE", message: "Invalid media type: \(mediaTypeRaw)", details: nil))
            return
        }
        guard let collection = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId], options: nil
        ).firstObject else {
            result(FlutterError(code: "NOT_FOUND", message: "Album not found: \(albumId)", details: nil))
            return
        }
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        switch mediaTypeRaw {
        case "image":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case "video":
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        default:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        }
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        guard let firstAsset = assets.firstObject else {
            result(FlutterError(code: "THUMBNAIL_ERROR", message: "No media found in album: \(albumId)", details: nil))
            return
        }
        let size = targetSize(from: args)
        let format = thumbnailFormat(from: args)
        requestThumbnailData(asset: firstAsset, targetWidth: size.width, targetHeight: size.height, format: format) { data, width, height, effectiveFormat in
            if let data = data {
                let payload = self.thumbnailMap(data: data, width: width, height: height, format: effectiveFormat)
                DispatchQueue.main.async { result(payload) }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_ERROR", message: "Could not generate thumbnail", details: nil))
                }
            }
        }
    }

    // MARK: - getThumbnailBatch

    private func getThumbnailBatch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments required", details: nil))
            return
        }
        var mediaIds: [String] = []
        if let strings = args["mediaIds"] as? [String] {
            mediaIds = strings
        } else if let bridged = args["mediaIds"] as? [Any] {
            mediaIds = bridged.compactMap { $0 as? String }
        } else if let array = args["mediaIds"] as? NSArray {
            mediaIds = array.compactMap { $0 as? String }
        }
        let size = targetSize(from: args)
        let format = thumbnailFormat(from: args)
        var results: [String: Any] = [:]

        func step(_ index: Int) {
            if index >= mediaIds.count {
                DispatchQueue.main.async { result(results) }
                return
            }
            let mediaId = mediaIds[index]
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaId], options: nil).firstObject else {
                step(index + 1)
                return
            }
            requestThumbnailData(asset: asset, targetWidth: size.width, targetHeight: size.height, format: format) { data, width, height, effectiveFormat in
                if let data = data {
                    results[mediaId] = [
                        "data": FlutterStandardTypedData(bytes: data),
                        "width": width,
                        "height": height,
                        "format": effectiveFormat,
                    ]
                }
                step(index + 1)
            }
        }
        step(0)
    }

    // MARK: - getOriginalBytes

    private func getOriginalBytes(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard hasReadPermission else {
            result(permissionError())
            return
        }
        guard let args = call.arguments as? [String: Any],
              let mediaId = args["mediaId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Media ID required", details: nil))
            return
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaId], options: nil).firstObject else {
            result(FlutterError(code: "NOT_FOUND", message: "Media not found: \(mediaId)", details: nil))
            return
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            result(FlutterError(code: "NOT_FOUND", message: "Media not found: \(mediaId)", details: nil))
            return
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        PHAssetResourceManager.default().writeData(for: resource, to: tempURL, options: options) { error in
            if error != nil {
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    result(FlutterError(code: "ICLOUD_NOT_DOWNLOADED", message: "Asset not locally downloaded", details: nil))
                }
                return
            }
            do {
                let data = try Data(contentsOf: tempURL)
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    result(FlutterError(code: "ICLOUD_NOT_DOWNLOADED", message: "Could not read asset data", details: nil))
                }
            }
        }
    }
}
