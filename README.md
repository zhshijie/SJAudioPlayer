
## AVPlayer 封装

### 前言

最近需要用到 `AVPlayer` 来进行音频的播放，但是 `AVPlayer` 各个版本的兼容问题，播放各个状态的转换异常混乱，所以就希望能够将 `AVPlayer` 进行封装。

封装希望达到以下目标：

1. 接口简单
2. 状态转换明确
3. 不需要考虑版本兼容问题


### 使用方法

##### 基础使用

1. 创建 player

```swift
let player = AudioPlayer()
player.delegate = self
```

2. 设置播放源
```swift
// 远程视频
self.audioPlayer.src = "https://store-g1.seewo.com/picbook/test.mp3"

// 本地视频
self.audioPlayer.src = Bundle.main.path(forResource: "test", ofType: "mp3")
```

3. 开始播放

```swift
 layer.play()
```

4. 暂停播放

```swift
 player.pause()
```

5. 拖动进度条

```swift
  player.seekTo(progress: 100)
```

6. 播放器状态回调

```swift
  func audioPlayer(_ audioPlayer: AudioPlayer, stateDidChanged state: AudioPlayerState) {
        switch state {
        case .none:
            break
        case .playing:
            break
        case .loading:
            break
        case .paused:
            break
        case .ended:
            break
        case .error:
            break
        }
    }
```

7. 进度条回调

```swift
func audioPlayer(_ audioPlayer: AudioPlayer, progressDidChanged progress: Float64) {

}
```

8. 加载进度回调
```swift
func audioPlayer(_ audioPlayer: AudioPlayer, loadedProgressDidChanged loadedProgress: Float64) {

}
```


#### 进阶设置

1. 设置进度条的回调时间间隔

```swift
player.intervalOfProgressObserver = 2 // 默认是 1s
```

2. 设置音频播放在被打断后，是否自动恢复

```swift
player.isAutoPlayAfterInterruption = false // 默认值是 true
```

### 后续功能优化

1. 添加加载超时功能

### 状态转换图

我们先抛开 `AVPlayer`，单纯的考虑一个音频播放器需要的状态，及各个状态之间的转换。我们需要先定义播发器的各个状态，和各个状态之间的转换动作。

#### 状态（State）

1. None - 初始状态，代表播发器刚刚创建时的状态
2. Loading - 加载状态，代表播放器正在加载数据，无论是加载本地数据还是网络数据
3. Playing - 播放状态，代表播发器处于播放状态
4. Paused - 暂停状态，代表播发器处于暂停状态
5. Ended - 结束状态，代表播发器处于播放结束状态
6. Error - 错误状态，代码播发器捕获到了错误


#### 动作（Action）

定义了播放器以下动作：

1. 点击播放
2. 点击暂停
3. 加载数据
4. 数据加载成功通知
4. 进度跳转
5. 发送错误
6. 切换数据源


其中，由于还有「播放点数据是否已经加载」整个变量，所以 1、4 这 2 个动作，可以细分成 4 个动作，如下：

1. 点击播放时，播放点击数据已加载
2. 点击播放时，播放点数据未加载
3. 进度跳转时，新播放点数据已加载
4. 进度跳转时，新播放点数据未加载

所以合并起来。一共有 8 个不同的动作

所有的动作和状态之间的转换关系如下图

![播放器状态转换图](https://github.com/zhshijie/SJAudioPlayer/blob/master/image/playerState.png?raw=true)


