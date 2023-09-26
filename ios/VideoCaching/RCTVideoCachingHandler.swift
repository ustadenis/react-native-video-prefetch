import Foundation
import AVFoundation
import DVAssetLoaderDelegate
import Promises

class RCTVideoCachingHandler: NSObject, DVAssetLoaderDelegatesDelegate {

    private var _m3u8VideoCache:RCTVideoCacheStorage! = RCTVideoCacheStorage.instance
    var playerItemPrepareText: ((AVAsset?, NSDictionary?) -> AVPlayerItem)?

    override init() {
        super.init()
    }
    
    func shouldCache(source: VideoSource, textTracks:[TextTrack]?) -> Bool {
        if source.isNetwork && source.shouldCache && ((textTracks == nil) || (textTracks!.count == 0)) {
            return true
        }
        /* The DVURLAsset created by cache doesn't have a tracksWithMediaType property, so trying
        * to bring in the text track code will crash. I suspect this is because the asset hasn't fully loaded.
        * Until this is fixed, we need to bypass caching when text tracks are specified.
        */
        DebugLog("Caching is not supported for uri '\(source.uri)' because text tracks are not compatible with the cache. Checkout https://github.com/react-native-community/react-native-video/blob/master/docs/caching.md")
        return false
    }
    
    func playerItemForSourceUsingCache(uri:String!, assetOptions options:NSDictionary!) -> Promise<AVPlayerItem?> {
        let url = URL(string: uri)
        return getItemForUri(uri)
        .then{ [weak self] (cachedAsset: AVAsset?) -> AVPlayerItem in
            guard let self = self else {
                throw  NSError(domain: "", code: 0, userInfo: nil)
            }

            if let cachedAsset = cachedAsset {
                DebugLog("Playing back uri '\(uri ?? "")' from cache")
                // See note in playerItemForSource about not being able to support text tracks & caching
                return AVPlayerItem(asset: cachedAsset)
            }

            let asset:DVURLAsset! = DVURLAsset(url:url, options:options as? [String : Any], networkTimeout:10000)
            asset.loaderDelegate = self
            
            /* More granular code to have control over the DVURLAsset
             let resourceLoaderDelegate = DVAssetLoaderDelegate(url: url)
             resourceLoaderDelegate.delegate = self
             let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false)
             components?.scheme = DVAssetLoaderDelegate.scheme()
             var asset: AVURLAsset? = nil
             if let url = components?.url {
             asset = AVURLAsset(url: url, options: options)
             }
             asset?.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
             */
            
            return AVPlayerItem(asset: asset)
        }
    }

    func getItemForUri(_ uri:String) ->  Promise<AVAsset?> {
        return Promise<AVAsset?> { [weak self] fulfill, reject in

            guard let assetURL = URL(string: uri) else {
                reject(NSError(domain: "", code: 2))
                return
            }

            let cachedAsset: AVAsset?

            if let localFileLocation = self?._m3u8VideoCache.storedItemUrl(forUri: assetURL.absoluteString) {
                cachedAsset = AVURLAsset(url: localFileLocation)
                self?._m3u8VideoCache.updateAsset(uri: uri, lastAccessedDate: Date())
            } else {
                cachedAsset = nil
            }

            fulfill(cachedAsset)
        }
    }
    
    // MARK: - DVAssetLoaderDelegate
    
    func dvAssetLoaderDelegate(loaderDelegate:DVAssetLoaderDelegate!, didLoadData data:NSData!, forURL url:NSURL!) {
//        _videoCache.storeItem(data as Data?, forUri:url.absoluteString, withCallback:{ (success:Bool) in
//            DebugLog("Cache data stored successfully 🎉")
//        })
    }
}

