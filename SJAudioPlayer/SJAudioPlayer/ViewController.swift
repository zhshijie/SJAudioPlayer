//
//  ViewController.swift
//  SJAudioPlayer
//
//  Created by Zsj on 2019/7/18.
//  Copyright © 2019 com.zsj.sjAudioPlayer. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var localAudioPlayOrPauseButton: UIButton!
    @IBOutlet weak var remoteAudioPlayOrPauseButton: UIButton!

    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    lazy var audioPlayer: AudioPlayer = {
        let player = AudioPlayer()
        player.delegate = self
        return player
    }()
    
    lazy var remoteURLString: String = {
        return "https://store-g1.seewo.com/picbook/test.mp3"
    }()
    
    lazy var localURLString: String = {
        return Bundle.main.path(forResource: "test", ofType: "mp3") ?? ""
    }()
    
    var isDragSlider = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.progressSlider.addTarget(self, action: #selector(seek), for: .touchUpInside)
        self.progressSlider.addTarget(self, action: #selector(beginSeek), for: .touchDragInside)
    }
    
    @IBAction func localAudioPlayOrPause(_ sender: UIButton) {
        
        if sender.isSelected {
            audioPlayer.pause()
        } else {
            if audioPlayer.src != localURLString {
                audioPlayer.src = localURLString
            }
            audioPlayer.play()
        }
    }
    
    @IBAction func remoteAudioPlayOrPause(_ sender: UIButton) {
        
        if sender.isSelected {
            audioPlayer.pause()
        } else {
            if audioPlayer.src != remoteURLString {
                audioPlayer.src = remoteURLString
            }
            audioPlayer.play()
        }
        
    }
    
    @objc func seek(){
        let progress = Float64(progressSlider.value) * (228.1273469387755)
        audioPlayer.seekTo(progress: Float64(progress))
        isDragSlider = false
    }
    
    @objc func beginSeek() {
        isDragSlider = true
    }
}


extension ViewController: AudioPlayerDelegate {
    
    func audioPlayer(_ audioPlayer: AudioPlayer, stateDidChanged state: AudioPlayerState) {
        
        print("audioPlayer state = \(state)")
        
        let relativeButton = audioPlayer.src == remoteURLString ? remoteAudioPlayOrPauseButton : localAudioPlayOrPauseButton
        let noRelativeButton = audioPlayer.src != remoteURLString ? remoteAudioPlayOrPauseButton : localAudioPlayOrPauseButton
        
        noRelativeButton?.isSelected = false
        noRelativeButton?.isHidden = false

        switch state {
        case .playing:
            relativeButton?.isSelected = true
            relativeButton?.isHidden = false
            loadingView.stopAnimating()
            break
        case .loading:
            loadingView.isHidden = false
            relativeButton?.isHidden = true
            loadingView.startAnimating()
            break
        case .paused, .none:
            relativeButton?.isSelected = false
            relativeButton?.isHidden = false
            loadingView.stopAnimating()
            break
        case .ended:
            relativeButton?.isSelected = false
            relativeButton?.isHidden = false
            loadingView.stopAnimating()
            break
        case .error:
            relativeButton?.isSelected = false
            relativeButton?.isHidden = false
            loadingView.stopAnimating()
            break
        }
        
    }
    
    func audioPlayer(_ audioPlayer: AudioPlayer, progressDidChanged progress: Float64) {
        
        switch audioPlayer.state {
        case .playing:
            guard isDragSlider == false else {
                return
            }
            progressSlider.value = Float(progress / audioPlayer.duration!)
            
            progressLabel.text = "\(Int(progress))"
            durationLabel.text = "\(Int(audioPlayer.duration!))"

            break
        default:
            break
        }
    }
    
    func audioPlayer(_ audioPlayer: AudioPlayer, loadedProgressDidChanged loadedProgress: Float64) {
    }
    
}
