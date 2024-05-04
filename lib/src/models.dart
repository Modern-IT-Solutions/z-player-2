import 'dart:convert';

import 'package:flutter/material.dart';

abstract class ZStream {
  final bool live;
  final int? size;
  final String src;
  final ZStreamType type;
  const ZStream({
    required this.src,
    required this.type,
    this.size,
    required this.live,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'size': size,
      'src': src,
      'type': type.name,
    };
  }

  factory ZStream.fromMap(Map<String, dynamic> map) {
    var type = map['type'] as String;
    switch (type) {
      case 'video':
        return ZVideoStream.fromMap(map);
      case 'audio':
        return ZAudioStream.fromMap(map);
      case 'muxed':
        return ZMuxedStream.fromMap(map);
      default:
        throw Exception("Unknown stream type");
    }
  }

  @override
  bool operator ==(covariant ZStream other) {
    if (identical(this, other)) return true;
    return other.src == src;
  }
}

class ZVideoStream extends ZStream {
  final Size resolution;
  final String qualityLabel;
  ZVideoStream({
    super.live = false,
    super.size,
    required super.src,
    required this.resolution,
    required this.qualityLabel,
  }) : super(type: ZStreamType.video);

  ZVideoStream copyWith({
    bool? live,
    int? size,
    String? src,
    Size? resolution,
    String? qualityLabel,
  }) {
    return ZVideoStream(
      live: live ?? this.live,
      size: size ?? this.size,
      src: src ?? this.src,
      resolution: resolution ?? this.resolution,
      qualityLabel: qualityLabel ?? this.qualityLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'live': live,
      'size': size,
      'src': src,
      'resolution': [resolution.width, resolution.height],
      'qualityLabel': qualityLabel,
      'type': type.name,
    };
  }

  factory ZVideoStream.fromMap(Map<String, dynamic> map) {
    return ZVideoStream(
      live: map['live'] as bool? ?? false,
      size: map['size'] as int?,
      src: map['src'] as String,
      resolution: Size(
        double.parse(map['resolution'][0].toString()),
        double.parse(map['resolution'][1].toString()),
      ),
      qualityLabel: map['qualityLabel'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ZVideoStream.fromJson(String source) =>
      ZVideoStream.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'ZVideoStream(src: $src, resolution: $resolution, qualityLabel: $qualityLabel)';

  @override
  int get hashCode =>
      src.hashCode ^ resolution.hashCode ^ qualityLabel.hashCode;
}

class ZMuxedStream extends ZStream implements ZVideoStream {
  final Size resolution;
  final String qualityLabel;
  ZMuxedStream({
    super.live = false,
    super.size,
    required super.src,
    required this.resolution,
    required this.qualityLabel,
  }) : super(type: ZStreamType.muxed);

  ZMuxedStream copyWith({
    bool? live,
    int? size,
    String? src,
    Size? resolution,
    String? qualityLabel,
  }) {
    return ZMuxedStream(
      live: live ?? this.live,
      size: size ?? this.size,
      src: src ?? this.src,
      resolution: resolution ?? this.resolution,
      qualityLabel: qualityLabel ?? this.qualityLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'live': live,
      'size': size,
      'src': src,
      'resolution': [resolution.width, resolution.height],
      'qualityLabel': qualityLabel,
      'type': type.name,
    };
  }

  factory ZMuxedStream.fromMap(Map<String, dynamic> map) {
    return ZMuxedStream(
      live: map['live'] as bool? ?? false,
      size: map['size'] as int?,
      src: map['src'] as String,
      resolution: Size(
        double.parse(map['resolution'][0].toString()),
        double.parse(map['resolution'][1].toString()),
      ),
      qualityLabel: map['qualityLabel'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ZMuxedStream.fromJson(String source) =>
      ZMuxedStream.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'ZMuxedStream(src: $src, resolution: $resolution, qualityLabel: $qualityLabel)';

  @override
  int get hashCode =>
      src.hashCode ^ resolution.hashCode ^ qualityLabel.hashCode;
}

class ZAudioStream extends ZStream {
  final String qualityLabel;
  ZAudioStream({
    super.live = false,
    super.size,
    required super.src,
    required this.qualityLabel,
  }) : super(type: ZStreamType.audio);

  ZAudioStream copyWith({
    bool? live,
    int? size,
    String? src,
    String? qualityLabel,
  }) {
    return ZAudioStream(
      live: live ?? this.live,
      size: size ?? this.size,
      src: src ?? this.src,
      qualityLabel: qualityLabel ?? this.qualityLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'live': live,
      'size': size,
      'src': src,
      'qualityLabel': qualityLabel,
      'type': type.name,
    };
  }

  factory ZAudioStream.fromMap(Map<String, dynamic> map) {
    return ZAudioStream(
      live: map['live'] as bool? ?? false,
      size: map['size'] as int?,
      src: map['src'] as String,
      qualityLabel: map['qualityLabel'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ZAudioStream.fromJson(String source) =>
      ZAudioStream.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'ZAudioStream(src: $src, qualityLabel: $qualityLabel)';

  @override
  int get hashCode => src.hashCode ^ qualityLabel.hashCode;
}

enum ZStreamType {
  video,
  audio,
  muxed,
}
