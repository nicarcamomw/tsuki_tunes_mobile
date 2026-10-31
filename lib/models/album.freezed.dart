// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'album.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Album {

@JsonKey(fromJson: jsonString) String get id;@JsonKey(defaultValue: 'Unknown Album') String get title;@JsonKey(defaultValue: '') String get coverUrl; String? get coverXl;@JsonKey(fromJson: jsonString) String get artistId;@JsonKey(defaultValue: 'Unknown Artist') String get artistName; String get releaseDate; String get recordType; int get fansCount; int get tracksCount; String? get link;@JsonKey(includeIfNull: false, toJson: _tracksToJson) List<Track> get tracks;
/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlbumCopyWith<Album> get copyWith => _$AlbumCopyWithImpl<Album>(this as Album, _$identity);

  /// Serializes this Album to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Album;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Album&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.coverXl, _this.coverXl) || other.coverXl == _this.coverXl)&&(identical(other.artistId, _this.artistId) || other.artistId == _this.artistId)&&(identical(other.artistName, _this.artistName) || other.artistName == _this.artistName)&&(identical(other.releaseDate, _this.releaseDate) || other.releaseDate == _this.releaseDate)&&(identical(other.recordType, _this.recordType) || other.recordType == _this.recordType)&&(identical(other.fansCount, _this.fansCount) || other.fansCount == _this.fansCount)&&(identical(other.tracksCount, _this.tracksCount) || other.tracksCount == _this.tracksCount)&&(identical(other.link, _this.link) || other.link == _this.link)&&const DeepCollectionEquality().equals(other.tracks, _this.tracks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Album;
  return Object.hash(runtimeType,_this.id,_this.title,_this.coverUrl,_this.coverXl,_this.artistId,_this.artistName,_this.releaseDate,_this.recordType,_this.fansCount,_this.tracksCount,_this.link,const DeepCollectionEquality().hash(_this.tracks));
}

@override
String toString() {
  final _this = this as Album;
  return 'Album(id: ${_this.id}, title: ${_this.title}, coverUrl: ${_this.coverUrl}, coverXl: ${_this.coverXl}, artistId: ${_this.artistId}, artistName: ${_this.artistName}, releaseDate: ${_this.releaseDate}, recordType: ${_this.recordType}, fansCount: ${_this.fansCount}, tracksCount: ${_this.tracksCount}, link: ${_this.link}, tracks: ${_this.tracks})';
}


}

/// @nodoc
abstract mixin class $AlbumCopyWith<$Res>  {
  factory $AlbumCopyWith(Album value, $Res Function(Album) _then) = _$AlbumCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Album') String title,@JsonKey(defaultValue: '') String coverUrl, String? coverXl,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: 'Unknown Artist') String artistName, String releaseDate, String recordType, int fansCount, int tracksCount, String? link,@JsonKey(includeIfNull: false, toJson: _tracksToJson) List<Track> tracks
});




}
/// @nodoc
class _$AlbumCopyWithImpl<$Res>
    implements $AlbumCopyWith<$Res> {
  _$AlbumCopyWithImpl(this._self, this._then);

  final Album _self;
  final $Res Function(Album) _then;

/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? coverUrl = null,Object? coverXl = freezed,Object? artistId = null,Object? artistName = null,Object? releaseDate = null,Object? recordType = null,Object? fansCount = null,Object? tracksCount = null,Object? link = freezed,Object? tracks = null,}) {
  return _then(Album(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,coverXl: freezed == coverXl ? _self.coverXl : coverXl // ignore: cast_nullable_to_non_nullable
as String?,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,fansCount: null == fansCount ? _self.fansCount : fansCount // ignore: cast_nullable_to_non_nullable
as int,tracksCount: null == tracksCount ? _self.tracksCount : tracksCount // ignore: cast_nullable_to_non_nullable
as int,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,
  ));
}

}


/// Adds pattern-matching-related methods to [Album].
extension AlbumPatterns on Album {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Album value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Album value)  $default,){
final _that = this;
switch (_that) {
case _Album():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Album value)?  $default,){
final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Album')  String title, @JsonKey(defaultValue: '')  String coverUrl,  String? coverXl, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName,  String releaseDate,  String recordType,  int fansCount,  int tracksCount,  String? link, @JsonKey(includeIfNull: false, toJson: _tracksToJson)  List<Track> tracks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that.id,_that.title,_that.coverUrl,_that.coverXl,_that.artistId,_that.artistName,_that.releaseDate,_that.recordType,_that.fansCount,_that.tracksCount,_that.link,_that.tracks);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Album')  String title, @JsonKey(defaultValue: '')  String coverUrl,  String? coverXl, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName,  String releaseDate,  String recordType,  int fansCount,  int tracksCount,  String? link, @JsonKey(includeIfNull: false, toJson: _tracksToJson)  List<Track> tracks)  $default,) {final _that = this;
switch (_that) {
case _Album():
return $default(_that.id,_that.title,_that.coverUrl,_that.coverXl,_that.artistId,_that.artistName,_that.releaseDate,_that.recordType,_that.fansCount,_that.tracksCount,_that.link,_that.tracks);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Album')  String title, @JsonKey(defaultValue: '')  String coverUrl,  String? coverXl, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName,  String releaseDate,  String recordType,  int fansCount,  int tracksCount,  String? link, @JsonKey(includeIfNull: false, toJson: _tracksToJson)  List<Track> tracks)?  $default,) {final _that = this;
switch (_that) {
case _Album() when $default != null:
return $default(_that.id,_that.title,_that.coverUrl,_that.coverXl,_that.artistId,_that.artistName,_that.releaseDate,_that.recordType,_that.fansCount,_that.tracksCount,_that.link,_that.tracks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Album extends Album {
  const _Album({@JsonKey(fromJson: jsonString) required this.id, @JsonKey(defaultValue: 'Unknown Album') required this.title, @JsonKey(defaultValue: '') required this.coverUrl, this.coverXl, @JsonKey(fromJson: jsonString) required this.artistId, @JsonKey(defaultValue: 'Unknown Artist') required this.artistName, this.releaseDate = '', this.recordType = 'album', this.fansCount = 0, this.tracksCount = 0, this.link, @JsonKey(includeIfNull: false, toJson: _tracksToJson)  List<Track> tracks = const []}): _tracks = tracks,super._();
  factory _Album.fromJson(Map<String, dynamic> json) => _$AlbumFromJson(json);

@override@JsonKey(fromJson: jsonString) final  String id;
@override@JsonKey(defaultValue: 'Unknown Album') final  String title;
@override@JsonKey(defaultValue: '') final  String coverUrl;
@override final  String? coverXl;
@override@JsonKey(fromJson: jsonString) final  String artistId;
@override@JsonKey(defaultValue: 'Unknown Artist') final  String artistName;
@override@JsonKey() final  String releaseDate;
@override@JsonKey() final  String recordType;
@override@JsonKey() final  int fansCount;
@override@JsonKey() final  int tracksCount;
@override final  String? link;
 final  List<Track> _tracks;
@override@JsonKey(includeIfNull: false, toJson: _tracksToJson) List<Track> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}


/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlbumCopyWith<_Album> get copyWith => __$AlbumCopyWithImpl<_Album>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlbumToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Album&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.coverXl, coverXl) || other.coverXl == coverXl)&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.recordType, recordType) || other.recordType == recordType)&&(identical(other.fansCount, fansCount) || other.fansCount == fansCount)&&(identical(other.tracksCount, tracksCount) || other.tracksCount == tracksCount)&&(identical(other.link, link) || other.link == link)&&const DeepCollectionEquality().equals(other.tracks, _tracks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,coverUrl,coverXl,artistId,artistName,releaseDate,recordType,fansCount,tracksCount,link,const DeepCollectionEquality().hash(_tracks));
}

@override
String toString() {
    return 'Album(id: $id, title: $title, coverUrl: $coverUrl, coverXl: $coverXl, artistId: $artistId, artistName: $artistName, releaseDate: $releaseDate, recordType: $recordType, fansCount: $fansCount, tracksCount: $tracksCount, link: $link, tracks: $tracks)';
}


}

/// @nodoc
abstract mixin class _$AlbumCopyWith<$Res> implements $AlbumCopyWith<$Res> {
  factory _$AlbumCopyWith(_Album value, $Res Function(_Album) _then) = __$AlbumCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Album') String title,@JsonKey(defaultValue: '') String coverUrl, String? coverXl,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: 'Unknown Artist') String artistName, String releaseDate, String recordType, int fansCount, int tracksCount, String? link,@JsonKey(includeIfNull: false, toJson: _tracksToJson) List<Track> tracks
});




}
/// @nodoc
class __$AlbumCopyWithImpl<$Res>
    implements _$AlbumCopyWith<$Res> {
  __$AlbumCopyWithImpl(this._self, this._then);

  final _Album _self;
  final $Res Function(_Album) _then;

/// Create a copy of Album
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? coverUrl = null,Object? coverXl = freezed,Object? artistId = null,Object? artistName = null,Object? releaseDate = null,Object? recordType = null,Object? fansCount = null,Object? tracksCount = null,Object? link = freezed,Object? tracks = null,}) {
  return _then(_Album(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,coverXl: freezed == coverXl ? _self.coverXl : coverXl // ignore: cast_nullable_to_non_nullable
as String?,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,fansCount: null == fansCount ? _self.fansCount : fansCount // ignore: cast_nullable_to_non_nullable
as int,tracksCount: null == tracksCount ? _self.tracksCount : tracksCount // ignore: cast_nullable_to_non_nullable
as int,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,
  ));
}


}

// dart format on
