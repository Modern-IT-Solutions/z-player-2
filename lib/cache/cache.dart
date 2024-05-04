// import 'package:isar/isar.dart';
// import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yte;

// part 'email.g.dart';

// @collection
// class VideoCache {
//   Id id = Isar.autoIncrement;

//   @Index(type: IndexType.value)
//   String? title;

//   yte.StreamManifest? manifest;

//   List<Recipient>? recipients;

//   @enumerated
//   Status status = Status.pending;
// }

// @embedded
// class Recipient {
//   String? name;

//   String? address;
// }

// enum Status {
//   draft,
//   pending,
//   sent,
// }