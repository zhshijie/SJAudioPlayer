//
//  AudioPlayer.swift
//  PicBook
//
//  Created by Zsj on 2019/6/23.
//  Copyright © 2019 张世杰. All rights reserved.
//

import Foundation
import AVFoundation

public enum AudioPlayerError: Error {
    case itemFailed
    case playerFailed
}

public enum AudioPlayerState {
    case none
    case loading
    case playing
    case paused
    case ended
    case error(error: AudioPlayerError)
}

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

public enum AudioPlayerLoadingState {
    case none
    case waitingLoadData
    case waitingPlay
}


public protocol AudioPlayerDelegate: NSObjectProtocol {
    
    func audioPlayer(_ audioPlayer: AudioPlayer, stateDidChanged state: AudioPlayerState)
    func audioPlayer(_ audioPlayer: AudioPlayer, progressDidChanged progress: Float64)
    func audioPlayer(_ audioPlayer: AudioPlayer, loadedProgressDidChanged loadedProgress: Float64)
    
}

public protocol AudioPlayerPlugin {
    
    /// 播放器开始处理 url
    func audioPlayerPrepare(url: URL) -> URL
    
}

public protocol AudioPlayerProperty {
    
    var audioPlayerID: AudioPlayerID { get }
    var delegate: AudioPlayerDelegate? { set get }
    
    var src: String? { set get }
    var state: AudioPlayerState { get }
    var progress: Float64 { get }
    var rate: Float { set get }
    var duration: Float64? { get }
    
    var intervalOfProgressObserver: Double { set get }
    var isAutoPlayAfterInterruption: Bool { set get }
    var isSeeking: Bool { get }
    
}

public protocol AudioPlayerAction {
    
    func play()
    
    func pause()
    
    func seekTo(progress: Float64, completionHandler: @escaping (Bool) -> Void)
    
}

// MARK: Constant
fileprivate extension AudioPlayer {
    
    static let fileURLPrefix = "file"
    static let remoteURLPrefix = "http"
    
    static let playerRateKeyPath = #keyPath(AVPlayer.rate)
    static let playerStatusKeyPath = #keyPath(AVPlayer.status)
    static let playerTimeControlStatusKeyPath = #keyPath(AVPlayer.timeControlStatus)
    static let playerReasonForWaitingToPlayKeyPath = #keyPath(AVPlayer.reasonForWaitingToPlay)
    
    static let playerItemStatusKeyPath = #keyPath(AVPlayer.currentItem.status)
    static let playerLoadedTimeRangesKeyPath = #keyPath(AVPlayer.currentItem.loadedTimeRanges)
    
}

public typealias AudioPlayerID = String

public class AudioPlayer: NSObject, AudioPlayerProperty {

    private var player: AVPlayer?
    
    private var plugins: [AudioPlayerPlugin] = []

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
    
    public fileprivate(set) var state: AudioPlayerState  {
        
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
    
    private var _periodicTimeObserver: Any?
    
    /// 设置进度的回调时间，默认是 1 s 回调一次
    public var intervalOfProgressObserver: Double = 1.0 {
        didSet {
            updatePeriodicTimeObserver()
        }
    }
    
    /// 音频正在播放时，如果被打断（电话），打断结束后是否继续播放，默认是 false，即在打断事件结束后，不会继续播放
    public var isAutoPlayAfterInterruption: Bool = true
    
    /// 是否处于正在 seek 的状态
    public fileprivate(set) var isSeeking: Bool = false
    
    private var seekProgress: Float64 = 0
    
    /// AVPlayer 的音频播放，从调用 play 到播放出声音，中间有 2 个中间状态
    /// 1. 从「调用play」到「开始下载音频数据」之间的状态
    /// 2. 从「开始下载音频数据」到「真正播放音频」
    /// 当 waitingLoadData ，代表处于状态 1
    /// 当 waitingPlay ，代表处于状态 2
    private var loadingState: AudioPlayerLoadingState = .none {
        didSet {
            guard loadingState != .none else {
                return
            }
            state = .loading
        }
    }

    /// 由于 player item 中的loadedTimeRanges，总是只存储当前正在加载的时间段，因此自己用一个数组
    /// 将已经加载的时间段存储下来
    private var loadedTimeRanges: [CMTimeRange] = []

    private var isAddPlayerItemKeyPathObserver: Bool = false
    
    init(plugins: [AudioPlayerPlugin] = []) {
        self.plugins = plugins
        super.init()
    }
    
    deinit {
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

// MARK: Observer
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
                if isSeeking && canPlay(in: seekProgress) {
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
            if isSeeking && canPlay(in: seekProgress) {
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
        
        addTimeRange(range)
        
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

// MARK: Private
extension AudioPlayer {
    
    func clearSrc(){
        pause()
        clearPeriodicTimeObserver()
        removePlayerItemKeyPathObserver()
        player?.replaceCurrentItem(with: nil)
    }
    
    func updateSrc(_ src: String) {
        
        guard let url = loadURL(string: src) else {
            clearSrc()
            return
        }
        
        removePlayerItemKeyPathObserver()
        loadedTimeRanges = []
        seekProgress = 0
        
        if player == nil {
            setupPlayer(with: url)
        } else {
            if _periodicTimeObserver != nil {
                delegate?.audioPlayer(self, progressDidChanged: 0)
            }
            let item = playerItem(url: url)
            player?.replaceCurrentItem(with: item)
        }
        
        updatePeriodicTimeObserver()
        addNotificationObserver()
        addPlayerItemKeyPathObserver()
        
    }
    
    func clearPeriodicTimeObserver() {
        if _periodicTimeObserver != nil {
            player?.removeTimeObserver(_periodicTimeObserver!)
            _periodicTimeObserver = nil
        }
    }
    
    func updatePeriodicTimeObserver() {
        guard let player = player else {
                return
        }
        clearPeriodicTimeObserver()
        
        let interval = CMTime(seconds: intervalOfProgressObserver, preferredTimescale: 1)
        _periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) {[weak self] (currentTime) in
            guard let `self` = self else {
                return
            }
            let progress = CMTimeGetSeconds(currentTime)
            self.delegate?.audioPlayer(self, progressDidChanged: progress)
            
            if self.loadingState == .waitingPlay && self.canPlay(player: player) && player.rate != 0{
                self.state = .playing
            }
        }
    }
    
    private func addTimeRange(_ timeRange: CMTimeRange) {
        
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
    
    private func setupPlayer(with url: URL) {
        
        player = AVPlayer(playerItem: playerItem(url: url))
        if #available(iOS 10.0, *) {
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        addPlayerKeyPathObserver()
        addNotificationObserver()
        
    }
    
    private func playerItem(url: URL) -> AVPlayerItem? {
        
        let isLocalURL = url.absoluteString.hasPrefix(AudioPlayer.fileURLPrefix)
        
        if isLocalURL {
            let asset = AVURLAsset(url: url)
            return AVPlayerItem(asset: asset)
        }
        
        return AVPlayerItem(url: url)
        
    }
    
    private func loadURL(string urlString: String) -> URL? {
        
        let isLocalURL = !urlString.hasPrefix(AudioPlayer.remoteURLPrefix)
        var url: URL?
        if isLocalURL{
            url = URL(fileURLWithPath: urlString)
        } else {
            url = URL(string: urlString)
        }
        
        plugins.forEach { (plugin) in
            guard let originURL = url else {
                return
            }
            url = plugin.audioPlayerPrepare(url: originURL)
        }
        
        return url
        
    }
    
    private func canPlay(player: AVPlayer) -> Bool {
        guard let currentItem = player.currentItem else {
            return false
        }
        let currentTime = CMTimeGetSeconds(currentItem.currentTime())
        return canPlay(in: currentTime)
    }
    
    private func canPlay(in progress: Float64) -> Bool {
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
    
    /// 检查 player 的 automaticallyWaitsToMinimizeStalling 是否是 true
    /// 由于 automaticallyWaitsToMinimizeStalling 只有在 iOS 10 及以后才支持，所以 iOS 10 以前的默认都返回 false
    /// - Parameter player: player
    private func checkAutomaticallyWaitsToMinimizeStalling(player: AVPlayer?) -> Bool {
        if #available(iOS 10, *) {
            if player?.automaticallyWaitsToMinimizeStalling == true {
                return true
            }
        }
        return false
    }
    
}


extension AVPlayerItem {
    
    // 是否播放到最后
    fileprivate func isEnd() -> Bool {
        let currentTime = CMTimeGetSeconds(self.currentTime())
        let duration = CMTimeGetSeconds(self.duration)
        if currentTime >= duration {
            return true
        }
        return false
    }
    
}
