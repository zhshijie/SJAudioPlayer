//
//  AudioPlayer+StateObserver.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation


// MARK: Constant
extension AudioPlayer {
    
    static let playerRateKeyPath = #keyPath(AVPlayer.rate)
    static let playerStatusKeyPath = #keyPath(AVPlayer.status)
    static let playerTimeControlStatusKeyPath = #keyPath(AVPlayer.timeControlStatus)
    static let playerReasonForWaitingToPlayKeyPath = #keyPath(AVPlayer.reasonForWaitingToPlay)
    
    static let playerItemStatusKeyPath = #keyPath(AVPlayer.currentItem.status)
    static let playerLoadedTimeRangesKeyPath = #keyPath(AVPlayer.currentItem.loadedTimeRanges)
    
}


extension AudioPlayer {
    
    func addNotificationObserver() {
        
        let center = NotificationCenter.default
        removeNotificationObserver()
        
        center.addObserver(self, selector: #selector(playbackFinished), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        center.addObserver(self, selector: #selector(playbackNewErrorLogEntry), name: .AVPlayerItemNewErrorLogEntry, object: nil)
        center.addObserver(self, selector: #selector(playbackFailedToPlayToEndTime), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        center.addObserver(self, selector: #selector(audioSessionInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        
    }
    
    func removeNotificationObserver() {
        
        let center = NotificationCenter.default
        center.removeObserver(self)
        
    }
    
    func addPlayerKeyPathObserver() {
        
        guard let player = player else {
            return
        }
        player.addObserver(self, forKeyPath: AudioPlayer.playerStatusKeyPath, options: [.new], context: nil)
        player.addObserver(self, forKeyPath: AudioPlayer.playerRateKeyPath, options: .new, context: nil)
        player.addObserver(self, forKeyPath: AudioPlayer.playerReasonForWaitingToPlayKeyPath, options: .new, context: nil)
        player.addObserver(self, forKeyPath: AudioPlayer.playerTimeControlStatusKeyPath, options: .new, context: nil)
        
    }
    
    func removePlayerKeyPathObserver() {
        
        guard let player = player else {
            return
        }
        player.removeObserver(self, forKeyPath: AudioPlayer.playerStatusKeyPath)
        player.removeObserver(self, forKeyPath: AudioPlayer.playerRateKeyPath)
        player.removeObserver(self, forKeyPath: AudioPlayer.playerReasonForWaitingToPlayKeyPath)
        player.removeObserver(self, forKeyPath: AudioPlayer.playerTimeControlStatusKeyPath)
        
    }
    
    func addPlayerItemKeyPathObserver() {
        
        guard let player = player else {
            return
        }
        guard isAddPlayerItemKeyPathObserver == false else {
            return
        }
        
        player.addObserver(self, forKeyPath: AudioPlayer.playerItemStatusKeyPath, options: [.initial, .new], context: nil)
        player.addObserver(self, forKeyPath: AudioPlayer.playerLoadedTimeRangesKeyPath, options: [.initial, .new], context: nil)
        
        isAddPlayerItemKeyPathObserver = true
    }
    
    func removePlayerItemKeyPathObserver() {
        
        guard let player = player else {
            return
        }
        guard isAddPlayerItemKeyPathObserver else {
            return
        }
        
        player.removeObserver(self, forKeyPath: AudioPlayer.playerItemStatusKeyPath)
        player.removeObserver(self, forKeyPath: AudioPlayer.playerLoadedTimeRangesKeyPath)
        
        isAddPlayerItemKeyPathObserver = false
    }
    
    /// 由于在 automaticallyWaitsToMinimizeStalling = false 时， 系统有时候会在音频还没有播放到结尾时，就收到了播放结束的通知
    /// 在收到该通知时，需要自己判断下，是否真的播放到了音频的尾部，如果不是，则不处理
    @objc func playbackFinished(notification: Notification) {
        
        guard let playerItem = notification.object as? AVPlayerItem else {
            return
        }
        
        guard playerItem.isEnd() else {
            return
        }
        state = .ended
    }
    
    @objc func playbackNewErrorLogEntry(notification: Notification) {
        
        state = .error(error: .playerFailed)
        
    }
    
    
    @objc func playbackFailedToPlayToEndTime(notification: Notification) {
        
        state = .error(error: .playerFailed)
        
    }
    
    @objc func audioSessionInterruption(notification: Notification) {
        
        guard let userInfo = notification.userInfo,
            let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue) else {
                return
        }
        
        switch interruptionType {
        case .began:
            break
        case .ended:
            
            guard let interruptionOptionRawValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let interruptionOption = AVAudioSession.InterruptionOptions(rawValue: interruptionOptionRawValue)
            if isAutoPlayAfterInterruption && interruptionOption == .shouldResume {
                guard let player = self.player else {
                    return
                }
                player.rate = self.rate
            }
            break
            
        @unknown default:
            break
        }
        
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath {
        case AudioPlayer.playerTimeControlStatusKeyPath:
            handlePlayerTimeControlStatusObserver(change: change)
            break
        case AudioPlayer.playerStatusKeyPath:
            handlePlayerStatusObserver(change: change)
            break
        case AudioPlayer.playerRateKeyPath:
            handlePlayerRateObserver(change: change)
            break
        case AudioPlayer.playerLoadedTimeRangesKeyPath:
            handlePlayerLoadedTimeRangesObserver(change: change)
            break
        case AudioPlayer.playerItemStatusKeyPath:
            handlePlayerItemStatusObserver(change: change)
            break
        default:
            break
        }
    }
    
    func handlePlayerTimeControlStatusObserver(change: [NSKeyValueChangeKey : Any]?) {
        if #available(iOS 10.0, *) {
            guard let rawValue = change?[.newKey] as? Int,
                let status = AVPlayer.TimeControlStatus(rawValue: rawValue) else {
                    return
            }
            
            if status == .waitingToPlayAtSpecifiedRate {
                // 如果是因为 seek 导致 status == .waitingToPlayAtSpecifiedRate,
                // 并且 seek 的进度点的相关数据已经加载过的，那么就不需要进入 waitingLoadData，直接返回就可以了
                if isSeeking && loadedTimeRangesManager.canPlay(in: seekProgress) {
                    return
                }
                self.loadingState = .waitingPlay
            }
        }
    }
    
    func handlePlayerStatusObserver(change: [NSKeyValueChangeKey : Any]?) {
        guard let statusRawValue = change?[.newKey] as? Int,
            let status = AVPlayer.Status(rawValue: statusRawValue) else {
                return
        }
        switch status {
        case .readyToPlay:
            break
        case .failed:
            state = .error(error: .playerFailed)
            break
        default:
            break
        }
    }
    
    /// 监听 player 的 rate 属性
    /// 除了以下情况，当 rate = 0 时，如果此时是 playing 或 loading 状态，则将 waitingToLoadData 设置为 true，
    /// 1. 如果是 seek 导致的 rate = 0， 并且 seek 的进度点的相关数据已经加载过的，那么不需要进入 waitingLoadData，直接返回就可以了
    /// 2. 如果是由于播放结束导致的 rate = 0，直接返回
    func handlePlayerRateObserver(change: [NSKeyValueChangeKey : Any]?) {
        guard let rate = change?[.newKey] as? Float else {
            return
        }
        
        guard rate == 0 else {
            return
        }
        
        guard let playerItem = player?.currentItem else {
            return
        }
        
        guard playerItem.isEnd() == false else {
            return
        }
        
        switch state {
        case .playing:
            // 如果是 seek 导致的 rate = 0， 并且 seek 的进度点的相关数据已经加载过的，那么就不需要进入 waitingLoadData，直接返回就可以了
            if isSeeking && loadedTimeRangesManager.canPlay(in: seekProgress) {
                return
            }
            self.loadingState = .waitingLoadData
        case .loading:
            self.loadingState = .waitingLoadData
            break
        default:
            break
        }
    }
    
    func handlePlayerLoadedTimeRangesObserver(change: [NSKeyValueChangeKey : Any]?) {
        guard let ranges = player?.currentItem?.loadedTimeRanges as? [CMTimeRange] else {
            return
        }
        guard let range = ranges.first else {
            return
        }
        
        let loadedProgress: Float64 = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration)
        self.delegate?.audioPlayer(self, loadedProgressDidChanged: loadedProgress)
        
        loadedTimeRangesManager.addTimeRange(range)
        
        guard let player = player else {
            return
        }
        
        if loadingState == .waitingLoadData {
            player.rate = rate
            loadingState = .waitingPlay
        }
    }
    
    func handlePlayerItemStatusObserver(change: [NSKeyValueChangeKey : Any]?) {
        guard let statusRawValue = change?[.newKey] as? Int,
            let status = AVPlayerItem.Status(rawValue: statusRawValue) else {
                return
        }
        
        switch status {
        case .readyToPlay:
            guard seekProgress > 0 else {
                return
            }
            seekTo(progress: seekProgress)
            break
        case .failed:
            state = .error(error: .itemFailed)
            break
        default:
            break
        }
    }
    
}
