//
//  URLManager.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

struct AudioPlayerURLManagerConstant {
    static let fileURLPrefix = "file"
    static let remoteURLPrefix = "http"
}

public class AudioPlayerURLManager {
    
    
    public static func loadURL(string urlString: String) -> URL? {
        
        let isLocalURL = !urlString.hasPrefix(AudioPlayerURLManagerConstant.remoteURLPrefix)
        var url: URL?
        if isLocalURL{
            url = URL(fileURLWithPath: urlString)
        } else {
            url = URL(string: urlString)
        }
        
        return url
        
    }
    
    public static func playerItem(url: URL) -> AVPlayerItem? {
        
        let isLocalURL = url.absoluteString.hasPrefix(AudioPlayerURLManagerConstant.fileURLPrefix)
        
        if isLocalURL {
            let asset = AVURLAsset(url: url)
            return AVPlayerItem(asset: asset)
        }
        
        return AVPlayerItem(url: url)
        
    }

    

}
