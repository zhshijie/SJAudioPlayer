//
//  AudioPlayerLoadedTimeRangesManager.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

class AudioPlayerLoadedTimeRangesManager {
    
    /// 由于 player item 中的 loadedTimeRanges，总是只存储当前正在加载的时间段，因此自己用一个数组
    /// 将已经加载的时间段存储下来
    private var loadedTimeRanges: [CMTimeRange] = []
    
    public func clear() {
        loadedTimeRanges = []
    }
    
    public func addTimeRange(_ timeRange: CMTimeRange) {
        
        self.loadedTimeRanges.append(timeRange)
        self.loadedTimeRanges.sort { (range1, range2) -> Bool in
            return range2.start > range1.start
        }
        
        guard self.loadedTimeRanges.count > 0 else {
            return
        }
        
        var tmpLoadedTimeRanges: [CMTimeRange] = []
        var tmpTimeRange: CMTimeRange? = nil
        self.loadedTimeRanges.forEach { (timeRange) in
            guard let beforeTimeRange = tmpTimeRange else {
                tmpTimeRange = timeRange
                return
            }
            
            if beforeTimeRange.start + beforeTimeRange.duration >= timeRange.start,
                beforeTimeRange.start + beforeTimeRange.duration <= timeRange.start + timeRange.duration {
                tmpTimeRange?.duration = timeRange.start + timeRange.duration - beforeTimeRange.start
            } else if beforeTimeRange.start + beforeTimeRange.duration < timeRange.start {
                tmpLoadedTimeRanges.append(beforeTimeRange)
                tmpTimeRange = timeRange
            }
        }
        if tmpTimeRange != nil {
            tmpLoadedTimeRanges.append(tmpTimeRange!)
        }
        
        self.loadedTimeRanges = tmpLoadedTimeRanges
        
    }
    
    public func canPlay(in progress: Float64) -> Bool {
        let loadedTimeRanges = self.loadedTimeRanges
        
        let index = loadedTimeRanges.firstIndex { (range) -> Bool in
            let startTime = CMTimeGetSeconds(range.start)
            let endTime = startTime + CMTimeGetSeconds(range.duration)
            let currentTime = progress
            return currentTime >= startTime && currentTime < endTime
        }
        
        guard index != nil else {
            return false
        }
        return true
    }

}
