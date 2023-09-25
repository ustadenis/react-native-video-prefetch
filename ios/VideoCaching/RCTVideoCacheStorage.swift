//
//  RCTVideoCachStorage.swift
//  react-native-video
//
//  Created by Gari Sarkisyan on 21.09.23.
//

import Foundation
import CryptoKit

class RCTVideoCacheStorage {

    static let instance = RCTVideoCacheStorage()

    private let UserDefaultsCacheInfoKey = "UserDefaultsCacheInfoKey"

    private var cacheInfo: CacheInfo {
        get {
            let cacheInfo: CacheInfo
            if let data = UserDefaults.standard.data(forKey: UserDefaultsCacheInfoKey),
                let existing = try? PropertyListDecoder().decode(CacheInfo.self, from: data) {
                cacheInfo = existing
            } else {
                cacheInfo = CacheInfo(assets: [], currentSize: 0)
            }
            return cacheInfo
        }

        set {
            let data = try? PropertyListEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: UserDefaultsCacheInfoKey)
        }
    }

    private var fileManager: FileManager { FileManager.default }
    private let videoCacheDownloader = RCTVideoCacheDownloader()

    private struct CacheInfo: Codable {
        private(set) var assets: [CachedAsset]
        private(set) var currentSize: Int64
        var cacheMaxSize: Int64 = 2 * 1024 * 1024 * 1024 // 2gb

        mutating func addAsset(_ newAsset: CachedAsset) {
            assets.append(newAsset)
            currentSize += newAsset.fileSize
        }

        mutating func removeAsset(uri: String) {
            let deletedSize: Int64 = assets.filter({ $0.uri == uri })
                .reduce(0, { $0 + $1.fileSize })
            currentSize -= deletedSize
            assets.removeAll(where: { $0.uri == uri })
        }

        mutating func updateAsset(uri: String, lastAccessedDate: Date) {
            guard let index = assets.firstIndex(where: { $0.uri == uri }) else {
                return
            }
            assets[index].lastAccessedDate = lastAccessedDate
        }

    }

    private struct CachedAsset: Codable {
        let uri: String
        let bookmark: Data
        let fileSize: Int64
        var lastAccessedDate: Date
    }

    private init() {
        purgeIfNeeded()
    }

    // MARK: - Prefetching

    func prefetchVideoForUrl(_ url: String) {
        let uri = url
        guard let url = URL(string: url) else {
            return
        }

        if storedItemUrl(forUri: uri) == nil {
            videoCacheDownloader.downloadVideoForUrl(uri)?
                .then { [weak self] downloadLocation in
                    self?.storeItem(from: downloadLocation, forUri: url)
                }
                .catch { [weak self] error in
                    self?.deleteAsset(uri)
                }
        }
    }

    func removeVideoForUrl(_ url: String) {
        deleteAsset(url)
        videoCacheDownloader.removeVideoForUrl(url)
    }

    func clearCache() {
        cacheInfo.assets.forEach {
            deleteAsset($0.uri)
        }
    }

    func updateAsset(uri: String, lastAccessedDate: Date) {
        cacheInfo.updateAsset(uri: uri, lastAccessedDate: lastAccessedDate)
    }

    func storedItemUrl(forUri uri: String) -> URL? {
        guard let localFileLocation = cacheInfo.assets.first(where: { $0.uri == uri})?.bookmark else {
            return nil
        }

        var bookmarkDataIsStale = false
        do {
            let url = try URL(resolvingBookmarkData: localFileLocation,
                              bookmarkDataIsStale: &bookmarkDataIsStale)

            if bookmarkDataIsStale {
                print("******** Bookmark data is stale!")
                return nil
            }

            return url
        } catch {
            print("******** Failed to create URL from bookmark with error: \(error)")
            return nil
        }
    }

    func deleteAsset(_ assetUri: String) {

        do {
            if let localFileLocation = storedItemUrl(forUri: assetUri) {
                try FileManager.default.removeItem(at: localFileLocation)

                cacheInfo.removeAsset(uri: assetUri)
            }
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    func setCacheMaxSize(_ newSize: Int64) {
        cacheInfo.cacheMaxSize = newSize
        purgeIfNeeded()
    }

    private func storeItem(from: URL, forUri url: URL) {

        do {
            let bookmark = try from.bookmarkData()
            let uri = url.absoluteString

            cacheInfo.assets
                .filter({ $0.uri == url.absoluteString && $0.bookmark != bookmark })
                .forEach {
                    deleteAsset($0.uri)
                }

            let fileSize = getSizeForItem(at: from)
            cacheInfo.addAsset(
                CachedAsset(
                    uri: uri,
                    bookmark: bookmark,
                    fileSize: fileSize,
                    lastAccessedDate: Date()
                )
            )

            purgeIfNeeded()
        } catch {
            print("Failed to create bookmarkData for download URL.")
        }
    }

    private func purgeIfNeeded() {
        let cacheInfo = cacheInfo

        guard cacheInfo.currentSize >= cacheInfo.cacheMaxSize else {
            return
        }

        let assetsOrderedByAccessDate = cacheInfo.assets.sorted {
            $0.lastAccessedDate < $1.lastAccessedDate
        }

        let overflowSize = cacheInfo.currentSize - cacheInfo.cacheMaxSize
        let purgeSize = cacheInfo.cacheMaxSize / 100 * 20 + overflowSize // 20% of cache max size
        var sizeToDelete: Int64 = 0
        var assetsToDelete = [CachedAsset]()
        for asset in assetsOrderedByAccessDate {
            if sizeToDelete < purgeSize {
                sizeToDelete += asset.fileSize
                assetsToDelete.append(asset)
            } else {
                break
            }
        }

        assetsToDelete.forEach {
            deleteAsset($0.uri)
        }
    }

    private func getSizeForItem(at itemPath: URL) -> Int64 {
        guard
            let itemDictionary = try? fileManager.attributesOfItem(atPath: itemPath.path),
            let itemSize = itemDictionary[FileAttributeKey.size] as? Int64,
            let itemType = itemDictionary[FileAttributeKey.type] as? FileAttributeType
        else {
            return 0
        }

        return itemType == FileAttributeType.typeDirectory
        ? allocatedSizeOfDirectory(at: itemPath)
        : itemSize
    }

    private func allocatedSizeOfDirectory(at directoryURL: URL) -> Int64 {
        let allocatedSizeResourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
        ]

        // We have to enumerate all directory contents, including subdirectories.
        guard
            let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                options: [],
                errorHandler: nil
            )
        else {
            return 0
        }

        return enumerator.reduce(0) { result, item -> Int64 in
            guard
                let contentItemURL = item as? URL,
                let resourceValues = try? contentItemURL.resourceValues(forKeys: allocatedSizeResourceKeys),
                resourceValues.isRegularFile ?? false
            else {
                return result
            }
            return result + Int64(resourceValues.fileSize ?? resourceValues.fileAllocatedSize ?? 0)
        }
    }
}
