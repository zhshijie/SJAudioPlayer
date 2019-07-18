//
//  AVPlayerItem+Tool.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

extension AVPlayerItem {
    
    // 是否播放到最后
    public func isEnd() -> Bool {
        let currentTime = CMTimeGetSeconds(self.currentTime())
        let duration = CMTimeGetSeconds(self.duration)
        if currentTime >= duration {
            return true
        }
        return false
    }
    
}
