//
//  AudioPlayer+Tool.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/19.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

extension AudioPlayer {
    
    func canPlay(player: AVPlayer) -> Bool {
        guard let currentItem = player.currentItem else {
            return false
        }
        let currentTime = CMTimeGetSeconds(currentItem.currentTime())
        return loadedTimeRangesManager.canPlay(in: currentTime)
    }
    
    /// 检查 player 的 automaticallyWaitsToMinimizeStalling 是否是 true
    /// 由于 automaticallyWaitsToMinimizeStalling 只有在 iOS 10 及以后才支持，所以 iOS 10 以前的默认都返回 false
    func checkAutomaticallyWaitsToMinimizeStalling(player: AVPlayer?) -> Bool {
        if #available(iOS 10, *) {
            if player?.automaticallyWaitsToMinimizeStalling == true {
                return true
            }
        }
        return false
    }
    
}
