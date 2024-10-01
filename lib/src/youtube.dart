import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
// ignore: depend_on_referenced_packages
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/videos/streams/stream_controller.dart';
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/reverse_engineering/models/stream_info_provider.dart';
// kisweb
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models.dart';

/// [Youtube] class for getting youtube video information and streams.
/// is singleton class.
class Youtube {
  /// [Youtube] class for getting youtube video information and streams.
  /// is singleton class.
  Youtube._();
  static final Youtube _instance = Youtube._();
  static Youtube get instance => _instance;
  final yte = YoutubeExplode();

  Map<String, Map<String, dynamic>>? _cache;

  Future<T?> load<T>(String key, {bool withExpire = false}) async {
    if (_cache == null) {
      await init();
    }
    var now = DateTime.now().millisecondsSinceEpoch;
    var data = _cache![key];
    if (data == null) {
      return null;
    }
    if (data["expireAt"] != null && data["expireAt"] < now) {
      // if expired
      _cache!.remove(key);
      await sync();
      return null;
    }
    return data["value"] as T?;
  }

  Future<void> remember<T>(String key, T value, [Duration? expireAt]) async {
    if (_cache == null) {
      await init();
    }
    var now = DateTime.now().millisecondsSinceEpoch;
    _cache![key] = {
      "value": value,
      "expireAt": expireAt == null ? null : now + expireAt.inMilliseconds,
    };
    await sync();
  }

  Future<void> clear() async {
    _cache = {};
    await sync();
  }

  Future<void> delete(String key) async {
    if (_cache == null) {
      await init();
    }
    _cache!.remove(key);
    await sync();
  }

  Future<void> sync() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString("zplayer_streams_cache", jsonEncode(_cache));
  }

  Future<void> init() async {
    var prefs = await SharedPreferences.getInstance();
    var cacheMap = prefs.getString("zplayer_streams_cache");
    cacheMap ??= "{}";
    _cache = Map<String, Map<String, dynamic>>.from(jsonDecode(cacheMap));
  }

  Future<Set<ZStream>> streams(String id, {bool? isLive}) async {
    // if (kDebugMode) {
    clear();
    // }
    var cached = await load<List>("zplayer_cache_video_$id");
    if (cached != null) {
      return cached
          .map((e) {
            return ZStream.fromMap(Map<String, dynamic>.from(e));
          })
          .cast<ZStream>()
          .toSet();
    }

    // get video response
    var controller = StreamController(YoutubeHttpClient());
    var response = await controller.getPlayerResponse(
        VideoId.fromString(id),
        kIsWeb
            ? {
                'context': {
                  'client': {
                    'clientName': 'ANDROID_CREATOR',
                    'clientVersion': '24.24.100',
                    'androidSdkVersion': 30,
                    // 'userAgent':
                    // 'com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip',
                    'hl': 'en',
                    'gl': 'US',
                    'utcOffsetMinutes': 0,
                  },
                },
              }
            : {
                'context': {
                  'client': {
                    'clientName': 'ANDROID',
                    'clientVersion': '19.09.37',
                    'androidSdkVersion': 30,
                    'userAgent': 'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip',
                    'hl': 'en',
                    'timeZone': 'UTC',
                    'utcOffsetMinutes': 0,
                  },
                },
              });

    Set<ZStream> data = response.hlsManifestUrl?.isNotEmpty == true
        ? {
            ZMuxedStream(
              qualityLabel: "auto",
              src: response.hlsManifestUrl!,
              live: true,
              resolution: const Size(1080, 720),
            )
          }
        : {
            ...response.streams
                // .where((element) {
                //   return element.codec.subtype == "webm";
                // })

                .map((stream) {
              if (stream.videoCodec?.isNotEmpty == true) {
                var resolution = Size(
                  stream.videoWidth?.toDouble() ?? 1080,
                  stream.videoHeight?.toDouble() ?? 1080,
                );
                var isLive = stream.qualityLabel == "DASH";

                if (stream.audioCodec?.isNotEmpty == true && stream.source != StreamSource.adaptive) {
                  return ZMuxedStream(
                    live: isLive,
                    src: stream.url.toString(),
                    resolution: resolution,
                    qualityLabel: stream.qualityLabel,
                  );
                }
                return ZVideoStream(
                  live: stream.qualityLabel == "DASH",
                  src: stream.url.toString(),
                  resolution: Size(
                    stream.videoWidth?.toDouble() ?? 1080,
                    stream.videoHeight?.toDouble() ?? 1080,
                  ),
                  qualityLabel: stream.qualityLabel,
                );
              } else if (stream.audioCodec?.isNotEmpty == true) {
                return ZAudioStream(
                  live: stream.qualityLabel == "DASH",
                  src: stream.url.toString(),
                  qualityLabel: stream.qualityLabel,
                );
              } else {
                throw Exception("Unknown stream type");
              }
            }).toSet()
          };

    var expire = Uri.parse(data.first.src).queryParameters["expire"];
    var expireDate = expire == null ? DateTime.now().add(Duration(hours: 1)) : DateTime.fromMillisecondsSinceEpoch(int.parse(expire) * 1000);
    var diff = expireDate.difference(DateTime.now());
    remember("zplayer_cache_video_$id", data.map((e) => e.toMap()).toList(), diff);
    return data;
  }
}
