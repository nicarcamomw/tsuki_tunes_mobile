// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'radar_release.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RadarRelease {

@JsonKey(fromJson: jsonString) String get albumId;@JsonKey(defaultValue: '') String get title;@JsonKey(fromJson: jsonString) String get artistId;@JsonKey(defaultValue: '') String get artistName;@JsonKey(defaultValue: '') String get coverUrl;@JsonKey(defaultValue: '') String get releaseDate;@JsonKey(defaultValue: 'album') String get recordType;@JsonKey(fromJson: jsonDateOrEpoch) DateTime get detectedAt;/// True when it appeared after the artist's baseline (a genuinely new drop),
/// false for releases that already existed when the radar started watching.
@JsonKey(fromJson: jsonIsTrue) bool get isNew;@JsonKey(fromJson: jsonIsNotFalse) bool get read;
/// Create a copy of RadarRelease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RadarReleaseCopyWith<RadarRelease> get copyWith => _$RadarReleaseCopyWithImpl<RadarRelease>(this as RadarRelease, _$identity);

  /// Serializes this RadarRelease to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RadarRelease;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadarRelease&&(identical(other.albumId, _this.albumId) || other.albumId == _this.albumId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.artistId, _this.artistId) || other.artistId == _this.artistId)&&(identical(other.artistName, _this.artistName) || other.artistName == _this.artistName)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.releaseDate, _this.releaseDate) || other.releaseDate == _this.releaseDate)&&(identical(other.recordType, _this.recordType) || other.recordType == _this.recordType)&&(identical(other.detectedAt, _this.detectedAt) || other.detectedAt == _this.detectedAt)&&(identical(other.isNew, _this.isNew) || other.isNew == _this.isNew)&&(identical(other.read, _this.read) || other.read == _this.read));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RadarRelease;
  return Object.hash(runtimeType,_this.albumId,_this.title,_this.artistId,_this.artistName,_this.coverUrl,_this.releaseDate,_this.recordType,_this.detectedAt,_this.isNew,_this.read);
}

@override
String toString() {
  final _this = this as RadarRelease;
  return 'RadarRelease(albumId: ${_this.albumId}, title: ${_this.title}, artistId: ${_this.artistId}, artistName: ${_this.artistName}, coverUrl: ${_this.coverUrl}, releaseDate: ${_this.releaseDate}, recordType: ${_this.recordType}, detectedAt: ${_this.detectedAt}, isNew: ${_this.isNew}, read: ${_this.read})';
}


}

/// @nodoc
abstract mixin class $RadarReleaseCopyWith<$Res>  {
  factory $RadarReleaseCopyWith(RadarRelease value, $Res Function(RadarRelease) _then) = _$RadarReleaseCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonString) String albumId,@JsonKey(defaultValue: '') String title,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: '') String artistName,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: '') String releaseDate,@JsonKey(defaultValue: 'album') String recordType,@JsonKey(fromJson: jsonDateOrEpoch) DateTime detectedAt,@JsonKey(fromJson: jsonIsTrue) bool isNew,@JsonKey(fromJson: jsonIsNotFalse) bool read
});




}
/// @nodoc
class _$RadarReleaseCopyWithImpl<$Res>
    implements $RadarReleaseCopyWith<$Res> {
  _$RadarReleaseCopyWithImpl(this._self, this._then);

  final RadarRelease _self;
  final $Res Function(RadarRelease) _then;

/// Create a copy of RadarRelease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? albumId = null,Object? title = null,Object? artistId = null,Object? artistName = null,Object? coverUrl = null,Object? releaseDate = null,Object? recordType = null,Object? detectedAt = null,Object? isNew = null,Object? read = null,}) {
  return _then(RadarRelease(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isNew: null == isNew ? _self.isNew : isNew // ignore: cast_nullable_to_non_nullable
as bool,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RadarRelease].
extension RadarReleasePatterns on RadarRelease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RadarRelease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RadarRelease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RadarRelease value)  $default,){
final _that = this;
switch (_that) {
case _RadarRelease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RadarRelease value)?  $default,){
final _that = this;
switch (_that) {
case _RadarRelease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String releaseDate, @JsonKey(defaultValue: 'album')  String recordType, @JsonKey(fromJson: jsonDateOrEpoch)  DateTime detectedAt, @JsonKey(fromJson: jsonIsTrue)  bool isNew, @JsonKey(fromJson: jsonIsNotFalse)  bool read)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RadarRelease() when $default != null:
return $default(_that.albumId,_that.title,_that.artistId,_that.artistName,_that.coverUrl,_that.releaseDate,_that.recordType,_that.detectedAt,_that.isNew,_that.read);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String releaseDate, @JsonKey(defaultValue: 'album')  String recordType, @JsonKey(fromJson: jsonDateOrEpoch)  DateTime detectedAt, @JsonKey(fromJson: jsonIsTrue)  bool isNew, @JsonKey(fromJson: jsonIsNotFalse)  bool read)  $default,) {final _that = this;
switch (_that) {
case _RadarRelease():
return $default(_that.albumId,_that.title,_that.artistId,_that.artistName,_that.coverUrl,_that.releaseDate,_that.recordType,_that.detectedAt,_that.isNew,_that.read);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String releaseDate, @JsonKey(defaultValue: 'album')  String recordType, @JsonKey(fromJson: jsonDateOrEpoch)  DateTime detectedAt, @JsonKey(fromJson: jsonIsTrue)  bool isNew, @JsonKey(fromJson: jsonIsNotFalse)  bool read)?  $default,) {final _that = this;
switch (_that) {
case _RadarRelease() when $default != null:
return $default(_that.albumId,_that.title,_that.artistId,_that.artistName,_that.coverUrl,_that.releaseDate,_that.recordType,_that.detectedAt,_that.isNew,_that.read);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RadarRelease extends RadarRelease {
  const _RadarRelease({@JsonKey(fromJson: jsonString) required this.albumId, @JsonKey(defaultValue: '') required this.title, @JsonKey(fromJson: jsonString) required this.artistId, @JsonKey(defaultValue: '') required this.artistName, @JsonKey(defaultValue: '') required this.coverUrl, @JsonKey(defaultValue: '') required this.releaseDate, @JsonKey(defaultValue: 'album') required this.recordType, @JsonKey(fromJson: jsonDateOrEpoch) required this.detectedAt, @JsonKey(fromJson: jsonIsTrue) required this.isNew, @JsonKey(fromJson: jsonIsNotFalse) required this.read}): super._();
  factory _RadarRelease.fromJson(Map<String, dynamic> json) => _$RadarReleaseFromJson(json);

@override@JsonKey(fromJson: jsonString) final  String albumId;
@override@JsonKey(defaultValue: '') final  String title;
@override@JsonKey(fromJson: jsonString) final  String artistId;
@override@JsonKey(defaultValue: '') final  String artistName;
@override@JsonKey(defaultValue: '') final  String coverUrl;
@override@JsonKey(defaultValue: '') final  String releaseDate;
@override@JsonKey(defaultValue: 'album') final  String recordType;
@override@JsonKey(fromJson: jsonDateOrEpoch) final  DateTime detectedAt;
/// True when it appeared after the artist's baseline (a genuinely new drop),
/// false for releases that already existed when the radar started watching.
@override@JsonKey(fromJson: jsonIsTrue) final  bool isNew;
@override@JsonKey(fromJson: jsonIsNotFalse) final  bool read;

/// Create a copy of RadarRelease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RadarReleaseCopyWith<_RadarRelease> get copyWith => __$RadarReleaseCopyWithImpl<_RadarRelease>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RadarReleaseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RadarRelease&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.title, title) || other.title == title)&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.recordType, recordType) || other.recordType == recordType)&&(identical(other.detectedAt, detectedAt) || other.detectedAt == detectedAt)&&(identical(other.isNew, isNew) || other.isNew == isNew)&&(identical(other.read, read) || other.read == read));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,albumId,title,artistId,artistName,coverUrl,releaseDate,recordType,detectedAt,isNew,read);
}

@override
String toString() {
    return 'RadarRelease(albumId: $albumId, title: $title, artistId: $artistId, artistName: $artistName, coverUrl: $coverUrl, releaseDate: $releaseDate, recordType: $recordType, detectedAt: $detectedAt, isNew: $isNew, read: $read)';
}


}

/// @nodoc
abstract mixin class _$RadarReleaseCopyWith<$Res> implements $RadarReleaseCopyWith<$Res> {
  factory _$RadarReleaseCopyWith(_RadarRelease value, $Res Function(_RadarRelease) _then) = __$RadarReleaseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonString) String albumId,@JsonKey(defaultValue: '') String title,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: '') String artistName,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: '') String releaseDate,@JsonKey(defaultValue: 'album') String recordType,@JsonKey(fromJson: jsonDateOrEpoch) DateTime detectedAt,@JsonKey(fromJson: jsonIsTrue) bool isNew,@JsonKey(fromJson: jsonIsNotFalse) bool read
});




}
/// @nodoc
class __$RadarReleaseCopyWithImpl<$Res>
    implements _$RadarReleaseCopyWith<$Res> {
  __$RadarReleaseCopyWithImpl(this._self, this._then);

  final _RadarRelease _self;
  final $Res Function(_RadarRelease) _then;

/// Create a copy of RadarRelease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? albumId = null,Object? title = null,Object? artistId = null,Object? artistName = null,Object? coverUrl = null,Object? releaseDate = null,Object? recordType = null,Object? detectedAt = null,Object? isNew = null,Object? read = null,}) {
  return _then(_RadarRelease(
albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String,recordType: null == recordType ? _self.recordType : recordType // ignore: cast_nullable_to_non_nullable
as String,detectedAt: null == detectedAt ? _self.detectedAt : detectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isNew: null == isNew ? _self.isNew : isNew // ignore: cast_nullable_to_non_nullable
as bool,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
