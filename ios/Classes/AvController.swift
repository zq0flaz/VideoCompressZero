
import AVFoundation

class AvController: NSObject {
    public func getVideoAsset(_ url:URL)->AVURLAsset {
        return AVURLAsset(url: url)
    }
    
    public func getTrack(_ asset: AVURLAsset) -> AVAssetTrack? {
        var track: AVAssetTrack? = nil
        let group = DispatchGroup()
        group.enter()
        asset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            if status == .loaded {
                track = asset.tracks(withMediaType: AVMediaType.video).first
            } else if let error = error {
                print("Failed to load tracks: \(error.localizedDescription)")
            }
            group.leave()
        })
        group.wait()
        return track
    }

    public func getVideoOrientation(_ path: String) -> Int? {
        let url = Utility.getPathUrl(path)
        let asset = getVideoAsset(url)
        guard let track = getTrack(asset) else {
            return nil
        }

        let txf = track.preferredTransform

        // Determine orientation based on rotation matrix
        if txf.a == 0 && txf.b == 1.0 && txf.c == -1.0 && txf.d == 0 {
            return 90   // Portrait
        } else if txf.a == 0 && txf.b == -1.0 && txf.c == 1.0 && txf.d == 0 {
            return 270  // Portrait upside down
        } else if txf.a == 1.0 && txf.b == 0 && txf.c == 0 && txf.d == 1.0 {
            return 0    // Landscape right
        } else if txf.a == -1.0 && txf.b == 0 && txf.c == 0 && txf.d == -1.0 {
            return 180  // Landscape left
        } else {
            return 0    // Default to 0°
        }
    }
    
    public func getMetaDataByTag(_ asset: AVAsset, key: String) -> String {
        for item in asset.commonMetadata {
            if item.commonKey?.rawValue == key {
                return item.stringValue ?? ""
            }
        }
        return ""
    }
}
