//
//  AudioPlayer+Code.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/19.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

extension AudioPlayerState: Equatable {
    public static func == (lhs: AudioPlayerState, rhs: AudioPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.loading, .loading): return true
        case (.playing, .playing): return true
        case (.paused, .paused): return true
        case (.ended, .ended): return true
        case (.error(let s1), .error(let s2)) where s1 == s2: return true
        case _: return false
        }
    }
}

public class AudioPlayer: NSObject, AudioPlayerProperty {
    
    var player: AVPlayer?
    
    var plugins: [AudioPlayerPlugin] = []
    
    public lazy var audioPlayerID: AudioPlayerID = UUID().uuidString
    
    public weak var delegate: AudioPlayerDelegate?
    
    public var src: String? {
        
        willSet {
            guard let urlString = newValue else {
                guard src != nil else {
                    return
                }
                clearSrc()
                return
            }
            updateSrc(urlString)
        }
        
    }
    
    private var _state: AudioPlayerState = .none {
        
        didSet {
            delegate?.audioPlayer(self, stateDidChanged: _state)
            
            switch _state {
            case .error, .playing, .paused, .ended:
                loadingState = .none
            case .loading:
                break
            default:
                break
            }
        }
        
    }
    
    public internal(set) var state: AudioPlayerState  {
        
        set {
            guard _state != newValue else {
                return
            }
            _state = newValue
        }
        
        get {
            return _state
        }
        
    }
    
    /// 播放进度，单位（秒）
    public var progress: Float64 {
        
        guard let currentTime = player?.currentItem?.currentTime() else {
            return 0
        }
        return CMTimeGetSeconds(currentTime)
        
    }
    
    public var rate: Float = 1.0 {
        
        didSet {
            player?.rate = rate
        }
        
    }
    
    /// 音频时长，单位（秒）
    /// 当音频还未加载时，是无法获取到音频的时长的，所以取到的数值有可能为 nil
    public var duration: Float64? {
        
        guard let duration = player?.currentItem?.duration else {
            return nil
        }
        guard duration != .indefinite else {
            return nil
        }
        return CMTimeGetSeconds(duration)
        
    }
    
    var _periodicTimeObserver: Any?
    
    /// 设置进度的回调时间，默认是 1s 回调一次
    public var intervalOfProgressObserver: Double = 1.0 {
        didSet {
            updatePeriodicTimeObserver()
        }
    }
    
    /// 音频正在播放时，如果被打断（电话），打断结束后是否继续播放，默认是 false，即在打断事件结束后，不会继续播放
    public var isAutoPlayAfterInterruption: Bool = true
    
    /// 是否处于正在 seek 的状态
    public fileprivate(set) var isSeeking: Bool = false
    
    var seekProgress: Float64 = 0
    
    /// AVPlayer 的音频播放，从调用 play 到播放出声音，中间有 2 个中间状态
    /// 1. 从「调用play」到「开始下载音频数据」之间的状态
    /// 2. 从「开始下载音频数据」到「真正播放音频」
    /// 当 waitingLoadData ，代表处于状态 1
    /// 当 waitingPlay ，代表处于状态 2
    var loadingState: AudioPlayerLoadingState = .none {
        didSet {
            guard loadingState != .none else {
                return
            }
            state = .loading
        }
    }
    
    /// 由于 player item 中的 loadedTimeRanges，总是只存储当前正在加载的时间段，因此自己用一个数组
    /// 将已经加载的时间段存储下来
    lazy var loadedTimeRangesManager: AudioPlayerLoadedTimeRangesManager = AudioPlayerLoadedTimeRangesManager()
    
    
    var isAddPlayerItemKeyPathObserver: Bool = false
    
    init(plugins: [AudioPlayerPlugin] = []) {
        self.plugins = plugins
        super.init()
    }
    
    deinit {
        clearSrc()
        clearPeriodicTimeObserver()
        removePlayerItemKeyPathObserver()
        removePlayerKeyPathObserver()
        removeNotificationObserver()
    }
    
}

// MARK: Public
extension AudioPlayer: AudioPlayerAction {
    
    public func play() {
        
        guard let player = player else {
            return
        }
        
        guard let _ = player.currentItem else {
            return
        }
        
        player.rate = rate
        
        // 如果 automaticallyWaitsToMinimizeStalling == false，那么直接判断能否有足够的缓存
        // 如果缓存足够，直接切换到 playing 状态，
        // 如果缓存不足，切换到 .waitingLoadData 状态
        guard checkAutomaticallyWaitsToMinimizeStalling(player: player) == false else {
            return
        }
        
        if self.canPlay(player: player) {
            state = .playing
        } else {
            loadingState = .waitingLoadData
        }
    }
    
    /// 暂停播放当前音频
    public func pause() {
        
        state = .paused
        
        guard let player = player else {
            return
        }
        player.pause()
        
    }
    
    public func seekTo(progress: Float64, completionHandler: @escaping (Bool) -> Void = { _ in }) {
        
        guard let player = player else {
            return
        }
        
        isSeeking = true
        seekProgress = progress
        player.rate = 0
        let seekTime = CMTimeMakeWithSeconds(progress, preferredTimescale: 1000)
        player.seek(to: seekTime) { [weak self] success in
            
            guard let `self` = self else {
                return
            }
            switch self.state {
            case .playing:
                player.rate = self.rate
                break
            case .loading:
                player.rate = self.rate
                if self.canPlay(player: player) {
                    self.state = .playing
                } else {
                    self.loadingState = .waitingLoadData
                }
                break
            default:
                break
            }
            self.isSeeking = false
            completionHandler(success)
        }
        
    }
    
}


