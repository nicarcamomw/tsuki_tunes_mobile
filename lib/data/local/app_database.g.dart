// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ListenedTracksTable extends ListenedTracks
    with TableInfo<$ListenedTracksTable, ListenedTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListenedTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumTitleMeta = const VerificationMeta(
    'albumTitle',
  );
  @override
  late final GeneratedColumn<String> albumTitle = GeneratedColumn<String>(
    'album_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumIdMeta = const VerificationMeta(
    'albumId',
  );
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
    'album_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewUrlMeta = const VerificationMeta(
    'previewUrl',
  );
  @override
  late final GeneratedColumn<String> previewUrl = GeneratedColumn<String>(
    'preview_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listenedAtMeta = const VerificationMeta(
    'listenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> listenedAt = GeneratedColumn<DateTime>(
    'listened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    uid,
    trackId,
    title,
    artistName,
    albumTitle,
    albumId,
    coverUrl,
    previewUrl,
    duration,
    listenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listened_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListenedTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    } else if (isInserting) {
      context.missing(_artistNameMeta);
    }
    if (data.containsKey('album_title')) {
      context.handle(
        _albumTitleMeta,
        albumTitle.isAcceptableOrUnknown(data['album_title']!, _albumTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_albumTitleMeta);
    }
    if (data.containsKey('album_id')) {
      context.handle(
        _albumIdMeta,
        albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta),
      );
    } else if (isInserting) {
      context.missing(_albumIdMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('preview_url')) {
      context.handle(
        _previewUrlMeta,
        previewUrl.isAcceptableOrUnknown(data['preview_url']!, _previewUrlMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('listened_at')) {
      context.handle(
        _listenedAtMeta,
        listenedAt.isAcceptableOrUnknown(data['listened_at']!, _listenedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, trackId};
  @override
  ListenedTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListenedTrack(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      )!,
      albumTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_title'],
      )!,
      albumId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_id'],
      )!,
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      )!,
      previewUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_url'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      listenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}listened_at'],
      ),
    );
  }

  @override
  $ListenedTracksTable createAlias(String alias) {
    return $ListenedTracksTable(attachedDatabase, alias);
  }
}

class ListenedTrack extends DataClass implements Insertable<ListenedTrack> {
  final String uid;
  final String trackId;
  final String title;
  final String artistName;
  final String albumTitle;
  final String albumId;
  final String coverUrl;
  final String previewUrl;
  final int duration;
  final DateTime? listenedAt;
  const ListenedTrack({
    required this.uid,
    required this.trackId,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.albumId,
    required this.coverUrl,
    required this.previewUrl,
    required this.duration,
    this.listenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['track_id'] = Variable<String>(trackId);
    map['title'] = Variable<String>(title);
    map['artist_name'] = Variable<String>(artistName);
    map['album_title'] = Variable<String>(albumTitle);
    map['album_id'] = Variable<String>(albumId);
    map['cover_url'] = Variable<String>(coverUrl);
    map['preview_url'] = Variable<String>(previewUrl);
    map['duration'] = Variable<int>(duration);
    if (!nullToAbsent || listenedAt != null) {
      map['listened_at'] = Variable<DateTime>(listenedAt);
    }
    return map;
  }

  ListenedTracksCompanion toCompanion(bool nullToAbsent) {
    return ListenedTracksCompanion(
      uid: Value(uid),
      trackId: Value(trackId),
      title: Value(title),
      artistName: Value(artistName),
      albumTitle: Value(albumTitle),
      albumId: Value(albumId),
      coverUrl: Value(coverUrl),
      previewUrl: Value(previewUrl),
      duration: Value(duration),
      listenedAt: listenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(listenedAt),
    );
  }

  factory ListenedTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListenedTrack(
      uid: serializer.fromJson<String>(json['uid']),
      trackId: serializer.fromJson<String>(json['trackId']),
      title: serializer.fromJson<String>(json['title']),
      artistName: serializer.fromJson<String>(json['artistName']),
      albumTitle: serializer.fromJson<String>(json['albumTitle']),
      albumId: serializer.fromJson<String>(json['albumId']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      previewUrl: serializer.fromJson<String>(json['previewUrl']),
      duration: serializer.fromJson<int>(json['duration']),
      listenedAt: serializer.fromJson<DateTime?>(json['listenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'trackId': serializer.toJson<String>(trackId),
      'title': serializer.toJson<String>(title),
      'artistName': serializer.toJson<String>(artistName),
      'albumTitle': serializer.toJson<String>(albumTitle),
      'albumId': serializer.toJson<String>(albumId),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'previewUrl': serializer.toJson<String>(previewUrl),
      'duration': serializer.toJson<int>(duration),
      'listenedAt': serializer.toJson<DateTime?>(listenedAt),
    };
  }

  ListenedTrack copyWith({
    String? uid,
    String? trackId,
    String? title,
    String? artistName,
    String? albumTitle,
    String? albumId,
    String? coverUrl,
    String? previewUrl,
    int? duration,
    Value<DateTime?> listenedAt = const Value.absent(),
  }) => ListenedTrack(
    uid: uid ?? this.uid,
    trackId: trackId ?? this.trackId,
    title: title ?? this.title,
    artistName: artistName ?? this.artistName,
    albumTitle: albumTitle ?? this.albumTitle,
    albumId: albumId ?? this.albumId,
    coverUrl: coverUrl ?? this.coverUrl,
    previewUrl: previewUrl ?? this.previewUrl,
    duration: duration ?? this.duration,
    listenedAt: listenedAt.present ? listenedAt.value : this.listenedAt,
  );
  ListenedTrack copyWithCompanion(ListenedTracksCompanion data) {
    return ListenedTrack(
      uid: data.uid.present ? data.uid.value : this.uid,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      title: data.title.present ? data.title.value : this.title,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      albumTitle: data.albumTitle.present
          ? data.albumTitle.value
          : this.albumTitle,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      previewUrl: data.previewUrl.present
          ? data.previewUrl.value
          : this.previewUrl,
      duration: data.duration.present ? data.duration.value : this.duration,
      listenedAt: data.listenedAt.present
          ? data.listenedAt.value
          : this.listenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListenedTrack(')
          ..write('uid: $uid, ')
          ..write('trackId: $trackId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumTitle: $albumTitle, ')
          ..write('albumId: $albumId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('duration: $duration, ')
          ..write('listenedAt: $listenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uid,
    trackId,
    title,
    artistName,
    albumTitle,
    albumId,
    coverUrl,
    previewUrl,
    duration,
    listenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListenedTrack &&
          other.uid == this.uid &&
          other.trackId == this.trackId &&
          other.title == this.title &&
          other.artistName == this.artistName &&
          other.albumTitle == this.albumTitle &&
          other.albumId == this.albumId &&
          other.coverUrl == this.coverUrl &&
          other.previewUrl == this.previewUrl &&
          other.duration == this.duration &&
          other.listenedAt == this.listenedAt);
}

class ListenedTracksCompanion extends UpdateCompanion<ListenedTrack> {
  final Value<String> uid;
  final Value<String> trackId;
  final Value<String> title;
  final Value<String> artistName;
  final Value<String> albumTitle;
  final Value<String> albumId;
  final Value<String> coverUrl;
  final Value<String> previewUrl;
  final Value<int> duration;
  final Value<DateTime?> listenedAt;
  final Value<int> rowid;
  const ListenedTracksCompanion({
    this.uid = const Value.absent(),
    this.trackId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistName = const Value.absent(),
    this.albumTitle = const Value.absent(),
    this.albumId = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.previewUrl = const Value.absent(),
    this.duration = const Value.absent(),
    this.listenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListenedTracksCompanion.insert({
    required String uid,
    required String trackId,
    required String title,
    required String artistName,
    required String albumTitle,
    required String albumId,
    required String coverUrl,
    this.previewUrl = const Value.absent(),
    required int duration,
    this.listenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uid = Value(uid),
       trackId = Value(trackId),
       title = Value(title),
       artistName = Value(artistName),
       albumTitle = Value(albumTitle),
       albumId = Value(albumId),
       coverUrl = Value(coverUrl),
       duration = Value(duration);
  static Insertable<ListenedTrack> custom({
    Expression<String>? uid,
    Expression<String>? trackId,
    Expression<String>? title,
    Expression<String>? artistName,
    Expression<String>? albumTitle,
    Expression<String>? albumId,
    Expression<String>? coverUrl,
    Expression<String>? previewUrl,
    Expression<int>? duration,
    Expression<DateTime>? listenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (trackId != null) 'track_id': trackId,
      if (title != null) 'title': title,
      if (artistName != null) 'artist_name': artistName,
      if (albumTitle != null) 'album_title': albumTitle,
      if (albumId != null) 'album_id': albumId,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (duration != null) 'duration': duration,
      if (listenedAt != null) 'listened_at': listenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListenedTracksCompanion copyWith({
    Value<String>? uid,
    Value<String>? trackId,
    Value<String>? title,
    Value<String>? artistName,
    Value<String>? albumTitle,
    Value<String>? albumId,
    Value<String>? coverUrl,
    Value<String>? previewUrl,
    Value<int>? duration,
    Value<DateTime?>? listenedAt,
    Value<int>? rowid,
  }) {
    return ListenedTracksCompanion(
      uid: uid ?? this.uid,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumTitle: albumTitle ?? this.albumTitle,
      albumId: albumId ?? this.albumId,
      coverUrl: coverUrl ?? this.coverUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      duration: duration ?? this.duration,
      listenedAt: listenedAt ?? this.listenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (albumTitle.present) {
      map['album_title'] = Variable<String>(albumTitle.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (previewUrl.present) {
      map['preview_url'] = Variable<String>(previewUrl.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (listenedAt.present) {
      map['listened_at'] = Variable<DateTime>(listenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListenedTracksCompanion(')
          ..write('uid: $uid, ')
          ..write('trackId: $trackId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('albumTitle: $albumTitle, ')
          ..write('albumId: $albumId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('previewUrl: $previewUrl, ')
          ..write('duration: $duration, ')
          ..write('listenedAt: $listenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uid, id, position, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String uid;
  final String id;
  final int position;
  final String json;
  const Playlist({
    required this.uid,
    required this.id,
    required this.position,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['json'] = Variable<String>(json);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      uid: Value(uid),
      id: Value(id),
      position: Value(position),
      json: Value(json),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      uid: serializer.fromJson<String>(json['uid']),
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'json': serializer.toJson<String>(json),
    };
  }

  Playlist copyWith({String? uid, String? id, int? position, String? json}) =>
      Playlist(
        uid: uid ?? this.uid,
        id: id ?? this.id,
        position: position ?? this.position,
        json: json ?? this.json,
      );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      uid: data.uid.present ? data.uid.value : this.uid,
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('uid: $uid, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, id, position, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.uid == this.uid &&
          other.id == this.id &&
          other.position == this.position &&
          other.json == this.json);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> uid;
  final Value<String> id;
  final Value<int> position;
  final Value<String> json;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.uid = const Value.absent(),
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String uid,
    required String id,
    required int position,
    required String json,
    this.rowid = const Value.absent(),
  }) : uid = Value(uid),
       id = Value(id),
       position = Value(position),
       json = Value(json);
  static Insertable<Playlist> custom({
    Expression<String>? uid,
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? uid,
    Value<String>? id,
    Value<int>? position,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      position: position ?? this.position,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('uid: $uid, ')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FollowedArtistsTable extends FollowedArtists
    with TableInfo<$FollowedArtistsTable, FollowedArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FollowedArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uid, artistId, position, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'followed_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<FollowedArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid, artistId};
  @override
  FollowedArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FollowedArtist(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $FollowedArtistsTable createAlias(String alias) {
    return $FollowedArtistsTable(attachedDatabase, alias);
  }
}

class FollowedArtist extends DataClass implements Insertable<FollowedArtist> {
  final String uid;
  final String artistId;
  final int position;
  final String json;
  const FollowedArtist({
    required this.uid,
    required this.artistId,
    required this.position,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['artist_id'] = Variable<String>(artistId);
    map['position'] = Variable<int>(position);
    map['json'] = Variable<String>(json);
    return map;
  }

  FollowedArtistsCompanion toCompanion(bool nullToAbsent) {
    return FollowedArtistsCompanion(
      uid: Value(uid),
      artistId: Value(artistId),
      position: Value(position),
      json: Value(json),
    );
  }

  factory FollowedArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FollowedArtist(
      uid: serializer.fromJson<String>(json['uid']),
      artistId: serializer.fromJson<String>(json['artistId']),
      position: serializer.fromJson<int>(json['position']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'artistId': serializer.toJson<String>(artistId),
      'position': serializer.toJson<int>(position),
      'json': serializer.toJson<String>(json),
    };
  }

  FollowedArtist copyWith({
    String? uid,
    String? artistId,
    int? position,
    String? json,
  }) => FollowedArtist(
    uid: uid ?? this.uid,
    artistId: artistId ?? this.artistId,
    position: position ?? this.position,
    json: json ?? this.json,
  );
  FollowedArtist copyWithCompanion(FollowedArtistsCompanion data) {
    return FollowedArtist(
      uid: data.uid.present ? data.uid.value : this.uid,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      position: data.position.present ? data.position.value : this.position,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FollowedArtist(')
          ..write('uid: $uid, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, artistId, position, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FollowedArtist &&
          other.uid == this.uid &&
          other.artistId == this.artistId &&
          other.position == this.position &&
          other.json == this.json);
}

class FollowedArtistsCompanion extends UpdateCompanion<FollowedArtist> {
  final Value<String> uid;
  final Value<String> artistId;
  final Value<int> position;
  final Value<String> json;
  final Value<int> rowid;
  const FollowedArtistsCompanion({
    this.uid = const Value.absent(),
    this.artistId = const Value.absent(),
    this.position = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FollowedArtistsCompanion.insert({
    required String uid,
    required String artistId,
    required int position,
    required String json,
    this.rowid = const Value.absent(),
  }) : uid = Value(uid),
       artistId = Value(artistId),
       position = Value(position),
       json = Value(json);
  static Insertable<FollowedArtist> custom({
    Expression<String>? uid,
    Expression<String>? artistId,
    Expression<int>? position,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (artistId != null) 'artist_id': artistId,
      if (position != null) 'position': position,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FollowedArtistsCompanion copyWith({
    Value<String>? uid,
    Value<String>? artistId,
    Value<int>? position,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return FollowedArtistsCompanion(
      uid: uid ?? this.uid,
      artistId: artistId ?? this.artistId,
      position: position ?? this.position,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FollowedArtistsCompanion(')
          ..write('uid: $uid, ')
          ..write('artistId: $artistId, ')
          ..write('position: $position, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ListenedTracksTable listenedTracks = $ListenedTracksTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $FollowedArtistsTable followedArtists = $FollowedArtistsTable(
    this,
  );
  late final Index listenedByAlbum = Index(
    'listened_by_album',
    'CREATE INDEX listened_by_album ON listened_tracks (uid, album_id)',
  );
  late final Index listenedByDate = Index(
    'listened_by_date',
    'CREATE INDEX listened_by_date ON listened_tracks (uid, listened_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    listenedTracks,
    playlists,
    followedArtists,
    listenedByAlbum,
    listenedByDate,
  ];
}

typedef $$ListenedTracksTableCreateCompanionBuilder =
    ListenedTracksCompanion Function({
      required String uid,
      required String trackId,
      required String title,
      required String artistName,
      required String albumTitle,
      required String albumId,
      required String coverUrl,
      Value<String> previewUrl,
      required int duration,
      Value<DateTime?> listenedAt,
      Value<int> rowid,
    });
typedef $$ListenedTracksTableUpdateCompanionBuilder =
    ListenedTracksCompanion Function({
      Value<String> uid,
      Value<String> trackId,
      Value<String> title,
      Value<String> artistName,
      Value<String> albumTitle,
      Value<String> albumId,
      Value<String> coverUrl,
      Value<String> previewUrl,
      Value<int> duration,
      Value<DateTime?> listenedAt,
      Value<int> rowid,
    });

class $$ListenedTracksTableFilterComposer
    extends Composer<_$AppDatabase, $ListenedTracksTable> {
  $$ListenedTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get listenedAt => $composableBuilder(
    column: $table.listenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListenedTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $ListenedTracksTable> {
  $$ListenedTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumId => $composableBuilder(
    column: $table.albumId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get listenedAt => $composableBuilder(
    column: $table.listenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListenedTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListenedTracksTable> {
  $$ListenedTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumTitle => $composableBuilder(
    column: $table.albumTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get previewUrl => $composableBuilder(
    column: $table.previewUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get listenedAt => $composableBuilder(
    column: $table.listenedAt,
    builder: (column) => column,
  );
}

class $$ListenedTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListenedTracksTable,
          ListenedTrack,
          $$ListenedTracksTableFilterComposer,
          $$ListenedTracksTableOrderingComposer,
          $$ListenedTracksTableAnnotationComposer,
          $$ListenedTracksTableCreateCompanionBuilder,
          $$ListenedTracksTableUpdateCompanionBuilder,
          (
            ListenedTrack,
            BaseReferences<_$AppDatabase, $ListenedTracksTable, ListenedTrack>,
          ),
          ListenedTrack,
          PrefetchHooks Function()
        > {
  $$ListenedTracksTableTableManager(
    _$AppDatabase db,
    $ListenedTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListenedTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListenedTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListenedTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artistName = const Value.absent(),
                Value<String> albumTitle = const Value.absent(),
                Value<String> albumId = const Value.absent(),
                Value<String> coverUrl = const Value.absent(),
                Value<String> previewUrl = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<DateTime?> listenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListenedTracksCompanion(
                uid: uid,
                trackId: trackId,
                title: title,
                artistName: artistName,
                albumTitle: albumTitle,
                albumId: albumId,
                coverUrl: coverUrl,
                previewUrl: previewUrl,
                duration: duration,
                listenedAt: listenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                required String trackId,
                required String title,
                required String artistName,
                required String albumTitle,
                required String albumId,
                required String coverUrl,
                Value<String> previewUrl = const Value.absent(),
                required int duration,
                Value<DateTime?> listenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListenedTracksCompanion.insert(
                uid: uid,
                trackId: trackId,
                title: title,
                artistName: artistName,
                albumTitle: albumTitle,
                albumId: albumId,
                coverUrl: coverUrl,
                previewUrl: previewUrl,
                duration: duration,
                listenedAt: listenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ListenedTracksTable, ListenedTrack>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ListenedTracksTable,
                    ListenedTrack
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListenedTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListenedTracksTable,
      ListenedTrack,
      $$ListenedTracksTableFilterComposer,
      $$ListenedTracksTableOrderingComposer,
      $$ListenedTracksTableAnnotationComposer,
      $$ListenedTracksTableCreateCompanionBuilder,
      $$ListenedTracksTableUpdateCompanionBuilder,
      (
        ListenedTrack,
        BaseReferences<_$AppDatabase, $ListenedTracksTable, ListenedTrack>,
      ),
      ListenedTrack,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String uid,
      required String id,
      required int position,
      required String json,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> uid,
      Value<String> id,
      Value<int> position,
      Value<String> json,
      Value<int> rowid,
    });

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
          Playlist,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                uid: uid,
                id: id,
                position: position,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                required String id,
                required int position,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                uid: uid,
                id: id,
                position: position,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
      Playlist,
      PrefetchHooks Function()
    >;
typedef $$FollowedArtistsTableCreateCompanionBuilder =
    FollowedArtistsCompanion Function({
      required String uid,
      required String artistId,
      required int position,
      required String json,
      Value<int> rowid,
    });
typedef $$FollowedArtistsTableUpdateCompanionBuilder =
    FollowedArtistsCompanion Function({
      Value<String> uid,
      Value<String> artistId,
      Value<int> position,
      Value<String> json,
      Value<int> rowid,
    });

class $$FollowedArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FollowedArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistId => $composableBuilder(
    column: $table.artistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FollowedArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$FollowedArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FollowedArtistsTable,
          FollowedArtist,
          $$FollowedArtistsTableFilterComposer,
          $$FollowedArtistsTableOrderingComposer,
          $$FollowedArtistsTableAnnotationComposer,
          $$FollowedArtistsTableCreateCompanionBuilder,
          $$FollowedArtistsTableUpdateCompanionBuilder,
          (
            FollowedArtist,
            BaseReferences<
              _$AppDatabase,
              $FollowedArtistsTable,
              FollowedArtist
            >,
          ),
          FollowedArtist,
          PrefetchHooks Function()
        > {
  $$FollowedArtistsTableTableManager(
    _$AppDatabase db,
    $FollowedArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FollowedArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FollowedArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FollowedArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FollowedArtistsCompanion(
                uid: uid,
                artistId: artistId,
                position: position,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                required String artistId,
                required int position,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => FollowedArtistsCompanion.insert(
                uid: uid,
                artistId: artistId,
                position: position,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FollowedArtistsTable, FollowedArtist>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FollowedArtistsTable,
                    FollowedArtist
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FollowedArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FollowedArtistsTable,
      FollowedArtist,
      $$FollowedArtistsTableFilterComposer,
      $$FollowedArtistsTableOrderingComposer,
      $$FollowedArtistsTableAnnotationComposer,
      $$FollowedArtistsTableCreateCompanionBuilder,
      $$FollowedArtistsTableUpdateCompanionBuilder,
      (
        FollowedArtist,
        BaseReferences<_$AppDatabase, $FollowedArtistsTable, FollowedArtist>,
      ),
      FollowedArtist,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ListenedTracksTableTableManager get listenedTracks =>
      $$ListenedTracksTableTableManager(_db, _db.listenedTracks);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$FollowedArtistsTableTableManager get followedArtists =>
      $$FollowedArtistsTableTableManager(_db, _db.followedArtists);
}
