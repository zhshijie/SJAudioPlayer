//
//  AudioPlayer+Time.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import Foundation
import AVFoundation

extension AudioPlayer {
    
    func clearPeriodicTimeObserver() {
     
        guard let periodicTimeObserver = _periodicTimeObserver else {
            return
        }
        player?.removeTimeObserver(periodicTimeObserver)
        _periodicTimeObserver = nil

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
            guard player.rate != 0 else {
                return
            }
            let progress = CMTimeGetSeconds(currentTime)
            self.delegate?.audioPlayer(self, progressDidChanged: progress)
            
            if self.loadingState == .waitingPlay && self.canPlay(player: player) {
                self.state = .playing
            }
        }
    }
    

    
}
