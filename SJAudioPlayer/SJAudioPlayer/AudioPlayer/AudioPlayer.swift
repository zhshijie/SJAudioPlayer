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

public typealias AudioPlayerID = String
