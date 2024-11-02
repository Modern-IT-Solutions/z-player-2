// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../zplayer.dart';

class ZPlayer extends StatefulWidget {
  // ensureInitialized
  static void ensureInitialized() {
    MediaKit.ensureInitialized();
  }

  final Widget? title;
  final Set<ZStream> streams;
  final Future<void> Function()? onEnterFullScreen;
  final Future<void> Function()? onExitFullScreen;
  final BoxFit fit;

  const ZPlayer({super.key,
  required this.streams,
  this.fit = BoxFit.contain,
  this.title,
  this.onEnterFullScreen,
  this.onExitFullScreen,
  });

  @override
  State<ZPlayer> createState() => _ZPlayerState();
}

class _ZPlayerState extends State<ZPlayer> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  late final videoPlayer = Player(
    configuration: const PlayerConfiguration(bufferSize: 7 * 1024 * 1024, title: 'ZPlayer'),
  );
  late final audioPlayer = Player(
      configuration: PlayerConfiguration(
    title: widget.title?.toString() ?? 'ZPlayer',
  ));

  late final videoController = VideoController(videoPlayer);
  late final audioController = VideoController(audioPlayer);

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await init();
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  Future<void> init() async {
    // then get the video data
    if (videos.isNotEmpty) {
      // select 720p if exists if not select random video
      var selected = videos.firstWhere(
        (element) => element.resolution.height >= 300,
        orElse: () {
          var list = videos.toList();
          return list.first;
        },
      );
      await openStream(selected);
      // bind();
    }
  }

  // bind
  void bind() {
    unbind();
    // bind video with audio
    _subscriptions.add(videoPlayer.stream.volume.listen((event) {
      audioPlayer.setVolume(event);
    }));
    if (selectedVideo?.live != true) {
      _subscriptions.add(videoPlayer.stream.position.listen((event) {
        if (event.inMilliseconds > audioPlayer.state.position.inMilliseconds + 1000 || event.inMilliseconds < audioPlayer.state.position.inMilliseconds - 1000) {
          audioPlayer.seek(event + const Duration(milliseconds: 50));
        }
      }));
      _subscriptions.add(videoPlayer.stream.rate.listen((event) {
        audioPlayer.setRate(event);
      }));
      _subscriptions.add(videoPlayer.stream.playing.listen((event) {
        if (event) {
          audioPlayer.play();
        } else {
          audioPlayer.pause();
        }
      }));
    }
    bool isPaused = false;
    _subscriptions.add(videoPlayer.stream.buffering.listen((event) {
      if (event) {
        audioPlayer.pause();
        isPaused = true;
      } else if (videoPlayer.state.playing && isPaused) {
        audioPlayer.play();
        isPaused = false;
      }
    }));
    // _subscriptions.add(videoPlayer.stream.buffer.listen((event) {

    // }));
    _bindAudioToVideo = true;
  }

  // unbind
  Future<void> unbind() async {
    // TODO: fix this
    for (var sub in _subscriptions) {
      try {
        sub.cancel();
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    _subscriptions.clear();
    _bindAudioToVideo = false;
  }

  Duration videoSavedPosition = Duration.zero;

  bool _bindAudioToVideo = false;

  Future<void> openStream(ZVideoStream stream) async {
    videoSavedPosition = videoPlayer.state.position;
    await videoPlayer.stop();
    await audioPlayer.stop();

    _bindAudioToVideo = stream is! ZMuxedStream;
    if (_bindAudioToVideo && audios.isNotEmpty) {
      await audioPlayer.open(Media(audios.first.src.toString()), play: false);
      bind();
    } else {
      await unbind();
    }
    await videoPlayer.open(Media(stream.src.toString()), play: false);

    // set the saved position if duration is > videoSavedPosition
    late StreamSubscription sub;
    sub = videoPlayer.stream.duration.listen((event) async {
      if (event > videoSavedPosition) {
        await videoPlayer.seek(videoSavedPosition);
      }
      sub.cancel();
    });
    await videoPlayer.play();

    // set the state
    setState(() {
      selectedVideo = stream;
    });
  }

  @override
  void dispose() {
    unbind();
    try {
      audioPlayer.dispose();
    } catch (e) {
      print("Exp:" + e.toString());
    }
    try {
      videoPlayer.dispose();
    } catch (e) {
      print("Exp:" + e.toString());
    }
    super.dispose();
  }

  ZVideoStream? selectedVideo;

  Size? get _selectedVideoSize {
    if (selectedVideo == null) {
      return null;
    }
    return selectedVideo!.resolution;
  }

  Set<ZVideoStream> get videos {
    return muxeds;
    return widget.streams.where((element) => element is ZVideoStream && 
      element.resolution.height <= 720
    ).cast<ZVideoStream>().toSet();
  }

  Set<ZAudioStream> get audios {
    return widget.streams.where((element) => element is ZAudioStream).cast<ZAudioStream>().toSet();
  }

  Set<ZMuxedStream> get muxeds {
    return widget.streams.where((element) => element is ZMuxedStream).cast<ZMuxedStream>().toSet();
  }

  Set<ZVideoStream> get videosByQuality {
    var map = <num, ZVideoStream>{};
    for (var element in videos) {
      map[element.resolution.height] = element;
    }
    return map.values.toSet();
  }

  // open select quality bottom sheet
  void openSelectQuality() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            for (var stream in videosByQuality)
              ListTile(
                enabled: stream.resolution.height != selectedVideo?.resolution.height,
                leading: stream.resolution.height == selectedVideo?.resolution.height ? const Icon(Icons.check) : const SizedBox(),
                selected: selectedVideo == stream,
                title: Text(stream.qualityLabel == "DASH"
                    ? "LIVE "
                        "(${stream.resolution.height.toInt()}p)"
                    : stream.qualityLabel),
                onTap: () {
                  openStream(stream);
                  Navigator.pop(context);
                },
                trailing: qualityBadge(stream.resolution.height),
              ),
          ],
        );
      },
    );
  }
  var currentRate = 1.0;
  // show select speed bottom sheet
  void openSelectSpeed() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            for (double speed in [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3 ,5])
              ListTile(
                // enabled: speed != currentRate,
                leading: speed == currentRate ? const Icon(Icons.check) : const SizedBox(),
                selected: speed == currentRate,
                title: Text("x$speed"),
                onTap: () {
                  videoController.player.setRate(speed);
                  setState(() {
                    currentRate = speed;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  Widget qualityBadge(double height) {
    if (height >= 2160) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          "4K",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      );
    } else if (height >= 1440) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          "2K",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      );
    } else if (height >= 1080) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            // decoration: BoxDecoration(
            //   borderRadius: BorderRadius.circular(3),
            //   border: Border.all(color: Colors.grey.withOpacity(.4)),
            // ),
            child: Text(
              "recommended",
              style: TextStyle(fontSize: 11, color: Colors.green),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              "FHD",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    } else if (height >= 720) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          "HD",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Color? color;
  @override
  Widget build(BuildContext context) {
    color = Theme.of(context).primaryColor;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: color ?? Colors.white,
            brightness: Brightness.dark,
          ),
          platform: TargetPlatform.iOS, // !kIsWeb && !Platform.isIOS ? TargetPlatform.windows : TargetPlatform.iOS,
        ),
      child: MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          seekBarPositionColor: color ?? Colors.white,
          seekBarThumbColor: color ?? Colors.white,
          topButtonBar: [
            _buildTitle(),
            const Spacer(),
            _buildLiveIndicator(),
          ],
          bottomButtonBar: [
            const MaterialDesktopSkipPreviousButton(),
            const MaterialDesktopPlayOrPauseButton(),
            const MaterialDesktopSkipNextButton(),
            const MaterialDesktopVolumeButton(),
            // const _MaterialDesktopPositionIndicator(),
            // videoController.player.stream.position
            StreamBuilder(
              stream: videoController.player.stream.position,
              builder: (context, snapshot) {
                return Text(
                  "${snapshot.data?.inMinutes ?? 0}:${(snapshot.data?.inSeconds ?? 0) % 60}"
                  " / "
                  "${videoController.player.state.duration.inMinutes}:${videoController.player.state.duration.inSeconds % 60}"
                  ,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                );
              },
            ),
    
            const Spacer(),
            _buildQualityButton(),
            _buildSpeedButton(),
            const MaterialDesktopFullscreenButton(),
          ],
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          seekBarPositionColor: color ?? Colors.white,
          seekBarThumbColor: color ?? Colors.white,
          topButtonBar: [
            _buildTitle(),
            const Spacer(),
            _buildLiveIndicator(),
          ],
          bottomButtonBar: [
            const MaterialDesktopSkipPreviousButton(),
            const MaterialDesktopPlayOrPauseButton(),
            const MaterialDesktopSkipNextButton(),
            const MaterialDesktopVolumeButton(),
            const MaterialDesktopPositionIndicator(),
            const Spacer(),
            _buildQualityButton(),
            _buildSpeedButton(),
            const MaterialDesktopFullscreenButton(),
          ],
        ),
        child: MaterialVideoControlsTheme(
          normal: MaterialVideoControlsThemeData(
            seekBarPositionColor: color ?? Colors.white,
            seekBarThumbColor: color ?? Colors.white,
            topButtonBar: [
              _buildQualityButton(),
              _buildSpeedButton(),
              _buildTitle(),
              const Spacer(),
              const Spacer(),
              const Spacer(),
              _buildLiveIndicator(),
            ],
          ),
          fullscreen: MaterialVideoControlsThemeData(
            seekBarPositionColor: color ?? Colors.white,
            seekBarThumbColor: color ?? Colors.white,
            brightnessGesture: true,
            volumeGesture: true,
            topButtonBar: [
              _buildQualityButton(),
              _buildSpeedButton(),
              _buildTitle(),
              const Spacer(),
              const Spacer(),
              const Spacer(),
              _buildLiveIndicator(),
            ],
          ),
            child: Video(
              fit: widget.fit,
              fill: color ?? Colors.black,
              controller: videoController,
              onEnterFullscreen: widget.onEnterFullScreen ?? () async {},
              onExitFullscreen: widget.onExitFullScreen ?? () async {},
            ),
        ),
      ),
    ),
    );
  }

  Widget _buildLiveIndicator() {
    return ColoredBox(
      color: Colors.green,
      child: selectedVideo?.live == true ? _LiveIndicator() : const SizedBox(),
    );
  }

  Widget _buildTitle() {
    return widget.title != null
        ? Flexible(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              child: widget.title!,
            ),
          )
        : const SizedBox();
  }

  MaterialDesktopCustomButton _buildQualityButton() {
    return MaterialDesktopCustomButton(
      onPressed: openSelectQuality,
      icon: StreamBuilder(
        stream: videoController.player.stream.playing,
        builder: (context, snapshot) {
          return Badge.count(
            backgroundColor: color,
            count: videosByQuality.length,
            child: const Icon(Icons.settings),
          );
        },
      ),
    );
  }

  MaterialDesktopCustomButton _buildSpeedButton() {
    return MaterialDesktopCustomButton(
      onPressed: openSelectSpeed,
      icon: StreamBuilder(
        stream: videoController.player.stream.rate,
        builder: (context, snapshot) {
          return Badge(
            backgroundColor: color,
            label: Text(currentRate.toStringAsFixed(1)),
            child: const Icon(Icons.speed),
          );
        },
      ),
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  @override
  _LiveIndicatorState createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          height: 15,
          child: Text(
            "LIVE",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FadeTransition(
          opacity: _animation,
          child:
              // circle 20px red
              Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}





