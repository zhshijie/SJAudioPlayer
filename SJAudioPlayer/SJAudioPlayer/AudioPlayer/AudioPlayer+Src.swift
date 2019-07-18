//
//  AudioPlayer+Src.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

extension AudioPlayer {
    
    func clearSrc(){
        pause()
        clearPeriodicTimeObserver()
        removePlayerItemKeyPathObserver()
        player?.replaceCurrentItem(with: nil)
    }
    
    func updateSrc(_ src: String) {
        
        guard var url = AudioPlayerURLManager.loadURL(string: src) else {
            clearSrc()
            return
        }
        
        plugins.forEach { (plugin) in
            url = plugin.audioPlayerPrepare(url: url)
        }
        
        removePlayerItemKeyPathObserver()
        loadedTimeRangesManager.clear()
        seekProgress = 0
        
        if player == nil {
            setupPlayer(with: url)
        } else {
            if _periodicTimeObserver != nil {
                delegate?.audioPlayer(self, progressDidChanged: 0)
            }
            let item = AudioPlayerURLManager.playerItem(url: url)
            player?.replaceCurrentItem(with: item)
        }
        
        updatePeriodicTimeObserver()
        addNotificationObserver()
        addPlayerItemKeyPathObserver()
        
    }
    
    func setupPlayer(with url: URL) {
        
        let playerItem = AudioPlayerURLManager.playerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        if #available(iOS 10.0, *) {
            player?.automaticallyWaitsToMinimizeStalling = false
        }
        addPlayerKeyPathObserver()
        addNotificationObserver()
        
    }
    

}
