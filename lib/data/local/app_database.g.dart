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
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<int> syncState = GeneratedColumn<int>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    syncState,
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
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
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
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_state'],
      )!,
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

  /// Whether the server has this row yet ([SyncState]; 0 is synced, a
  /// literal so the saved schema snapshots can hold it).
  final int syncState;
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
    required this.syncState,
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
    map['sync_state'] = Variable<int>(syncState);
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
      syncState: Value(syncState),
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
      syncState: serializer.fromJson<int>(json['syncState']),
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
      'syncState': serializer.toJson<int>(syncState),
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
    int? syncState,
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
    syncState: syncState ?? this.syncState,
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
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
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
          ..write('listenedAt: $listenedAt, ')
          ..write('syncState: $syncState')
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
    syncState,
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
          other.listenedAt == this.listenedAt &&
          other.syncState == this.syncState);
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
  final Value<int> syncState;
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
    this.syncState = const Value.absent(),
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
    this.syncState = const Value.absent(),
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
    Expression<int>? syncState,
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
      if (syncState != null) 'sync_state': syncState,
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
    Value<int>? syncState,
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
      syncState: syncState ?? this.syncState,
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
    if (syncState.present) {
      map['sync_state'] = Variable<int>(syncState.value);
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
          ..write('syncState: $syncState, ')
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

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uid,
    kind,
    entityId,
    payload,
    attempts,
    nextAttemptAt,
    createdAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String uid;

  /// What to do (see OutboxKind), on which entity, with what data.
  final String kind;
  final String entityId;
  final String payload;
  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final String? lastError;
  const OutboxData({
    required this.id,
    required this.uid,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uid'] = Variable<String>(uid);
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      uid: Value(uid),
      kind: Value(kind),
      entityId: Value(entityId),
      payload: Value(payload),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      createdAt: Value(createdAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      uid: serializer.fromJson<String>(json['uid']),
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uid': serializer.toJson<String>(uid),
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxData copyWith({
    int? id,
    String? uid,
    String? kind,
    String? entityId,
    String? payload,
    int? attempts,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxData(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      uid: data.uid.present ? data.uid.value : this.uid,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uid,
    kind,
    entityId,
    payload,
    attempts,
    nextAttemptAt,
    createdAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.uid == this.uid &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> uid;
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<DateTime> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<String?> lastError;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.uid = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String uid,
    required String kind,
    required String entityId,
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime nextAttemptAt,
    required DateTime createdAt,
    this.lastError = const Value.absent(),
  }) : uid = Value(uid),
       kind = Value(kind),
       entityId = Value(entityId),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? uid,
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uid != null) 'uid': uid,
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? uid,
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? payload,
    Value<int>? attempts,
    Value<DateTime>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<String?>? lastError,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('uid: $uid, ')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastError: $lastError')
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
  late final $OutboxTable outbox = $OutboxTable(this);
  late final Index listenedByAlbum = Index(
    'listened_by_album',
    'CREATE INDEX listened_by_album ON listened_tracks (uid, album_id)',
  );
  late final Index listenedByDate = Index(
    'listened_by_date',
    'CREATE INDEX listened_by_date ON listened_tracks (uid, listened_at)',
  );
  late final Index outboxDue = Index(
    'outbox_due',
    'CREATE INDEX outbox_due ON outbox (uid, next_attempt_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    listenedTracks,
    playlists,
    followedArtists,
    outbox,
    listenedByAlbum,
    listenedByDate,
    outboxDue,
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
      Value<int> syncState,
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
      Value<int> syncState,
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

  ColumnFilters<int> get syncState => $composableBuilder(
    column: $table.syncState,
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

  ColumnOrderings<int> get syncState => $composableBuilder(
    column: $table.syncState,
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

  GeneratedColumn<int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
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
                Value<int> syncState = const Value.absent(),
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
                syncState: syncState,
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
                Value<int> syncState = const Value.absent(),
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
                syncState: syncState,
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
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String uid,
      required String kind,
      required String entityId,
      Value<String> payload,
      Value<int> attempts,
      required DateTime nextAttemptAt,
      required DateTime createdAt,
      Value<String?> lastError,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> uid,
      Value<String> kind,
      Value<String> entityId,
      Value<String> payload,
      Value<int> attempts,
      Value<DateTime> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<String?> lastError,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                uid: uid,
                kind: kind,
                entityId: entityId,
                payload: payload,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uid,
                required String kind,
                required String entityId,
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required DateTime nextAttemptAt,
                required DateTime createdAt,
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                uid: uid,
                kind: kind,
                entityId: entityId,
                payload: payload,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxData>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
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

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
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
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
}
