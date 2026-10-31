// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wrapped_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WrappedTrackEntry {

@JsonKey(defaultValue: '') String get trackId;@JsonKey(defaultValue: '') String get title;@JsonKey(defaultValue: '') String get artistName;@JsonKey(defaultValue: '') String get albumTitle;@JsonKey(defaultValue: '') String get coverUrl;@JsonKey(defaultValue: 0) int get playCount;@JsonKey(defaultValue: 0) int get totalSeconds;
/// Create a copy of WrappedTrackEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedTrackEntryCopyWith<WrappedTrackEntry> get copyWith => _$WrappedTrackEntryCopyWithImpl<WrappedTrackEntry>(this as WrappedTrackEntry, _$identity);

  /// Serializes this WrappedTrackEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WrappedTrackEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedTrackEntry&&(identical(other.trackId, _this.trackId) || other.trackId == _this.trackId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.artistName, _this.artistName) || other.artistName == _this.artistName)&&(identical(other.albumTitle, _this.albumTitle) || other.albumTitle == _this.albumTitle)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.playCount, _this.playCount) || other.playCount == _this.playCount)&&(identical(other.totalSeconds, _this.totalSeconds) || other.totalSeconds == _this.totalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WrappedTrackEntry;
  return Object.hash(runtimeType,_this.trackId,_this.title,_this.artistName,_this.albumTitle,_this.coverUrl,_this.playCount,_this.totalSeconds);
}

@override
String toString() {
  final _this = this as WrappedTrackEntry;
  return 'WrappedTrackEntry(trackId: ${_this.trackId}, title: ${_this.title}, artistName: ${_this.artistName}, albumTitle: ${_this.albumTitle}, coverUrl: ${_this.coverUrl}, playCount: ${_this.playCount}, totalSeconds: ${_this.totalSeconds})';
}


}

/// @nodoc
abstract mixin class $WrappedTrackEntryCopyWith<$Res>  {
  factory $WrappedTrackEntryCopyWith(WrappedTrackEntry value, $Res Function(WrappedTrackEntry) _then) = _$WrappedTrackEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: '') String trackId,@JsonKey(defaultValue: '') String title,@JsonKey(defaultValue: '') String artistName,@JsonKey(defaultValue: '') String albumTitle,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: 0) int playCount,@JsonKey(defaultValue: 0) int totalSeconds
});




}
/// @nodoc
class _$WrappedTrackEntryCopyWithImpl<$Res>
    implements $WrappedTrackEntryCopyWith<$Res> {
  _$WrappedTrackEntryCopyWithImpl(this._self, this._then);

  final WrappedTrackEntry _self;
  final $Res Function(WrappedTrackEntry) _then;

/// Create a copy of WrappedTrackEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackId = null,Object? title = null,Object? artistName = null,Object? albumTitle = null,Object? coverUrl = null,Object? playCount = null,Object? totalSeconds = null,}) {
  return _then(WrappedTrackEntry(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,playCount: null == playCount ? _self.playCount : playCount // ignore: cast_nullable_to_non_nullable
as int,totalSeconds: null == totalSeconds ? _self.totalSeconds : totalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WrappedTrackEntry].
extension WrappedTrackEntryPatterns on WrappedTrackEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WrappedTrackEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WrappedTrackEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WrappedTrackEntry value)  $default,){
final _that = this;
switch (_that) {
case _WrappedTrackEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WrappedTrackEntry value)?  $default,){
final _that = this;
switch (_that) {
case _WrappedTrackEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String trackId, @JsonKey(defaultValue: '')  String title, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WrappedTrackEntry() when $default != null:
return $default(_that.trackId,_that.title,_that.artistName,_that.albumTitle,_that.coverUrl,_that.playCount,_that.totalSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String trackId, @JsonKey(defaultValue: '')  String title, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds)  $default,) {final _that = this;
switch (_that) {
case _WrappedTrackEntry():
return $default(_that.trackId,_that.title,_that.artistName,_that.albumTitle,_that.coverUrl,_that.playCount,_that.totalSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(defaultValue: '')  String trackId, @JsonKey(defaultValue: '')  String title, @JsonKey(defaultValue: '')  String artistName, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds)?  $default,) {final _that = this;
switch (_that) {
case _WrappedTrackEntry() when $default != null:
return $default(_that.trackId,_that.title,_that.artistName,_that.albumTitle,_that.coverUrl,_that.playCount,_that.totalSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WrappedTrackEntry implements WrappedTrackEntry {
  const _WrappedTrackEntry({@JsonKey(defaultValue: '') required this.trackId, @JsonKey(defaultValue: '') required this.title, @JsonKey(defaultValue: '') required this.artistName, @JsonKey(defaultValue: '') required this.albumTitle, @JsonKey(defaultValue: '') required this.coverUrl, @JsonKey(defaultValue: 0) required this.playCount, @JsonKey(defaultValue: 0) required this.totalSeconds});
  factory _WrappedTrackEntry.fromJson(Map<String, dynamic> json) => _$WrappedTrackEntryFromJson(json);

@override@JsonKey(defaultValue: '') final  String trackId;
@override@JsonKey(defaultValue: '') final  String title;
@override@JsonKey(defaultValue: '') final  String artistName;
@override@JsonKey(defaultValue: '') final  String albumTitle;
@override@JsonKey(defaultValue: '') final  String coverUrl;
@override@JsonKey(defaultValue: 0) final  int playCount;
@override@JsonKey(defaultValue: 0) final  int totalSeconds;

/// Create a copy of WrappedTrackEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WrappedTrackEntryCopyWith<_WrappedTrackEntry> get copyWith => __$WrappedTrackEntryCopyWithImpl<_WrappedTrackEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WrappedTrackEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WrappedTrackEntry&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.title, title) || other.title == title)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.albumTitle, albumTitle) || other.albumTitle == albumTitle)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.playCount, playCount) || other.playCount == playCount)&&(identical(other.totalSeconds, totalSeconds) || other.totalSeconds == totalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,trackId,title,artistName,albumTitle,coverUrl,playCount,totalSeconds);
}

@override
String toString() {
    return 'WrappedTrackEntry(trackId: $trackId, title: $title, artistName: $artistName, albumTitle: $albumTitle, coverUrl: $coverUrl, playCount: $playCount, totalSeconds: $totalSeconds)';
}


}

/// @nodoc
abstract mixin class _$WrappedTrackEntryCopyWith<$Res> implements $WrappedTrackEntryCopyWith<$Res> {
  factory _$WrappedTrackEntryCopyWith(_WrappedTrackEntry value, $Res Function(_WrappedTrackEntry) _then) = __$WrappedTrackEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(defaultValue: '') String trackId,@JsonKey(defaultValue: '') String title,@JsonKey(defaultValue: '') String artistName,@JsonKey(defaultValue: '') String albumTitle,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: 0) int playCount,@JsonKey(defaultValue: 0) int totalSeconds
});




}
/// @nodoc
class __$WrappedTrackEntryCopyWithImpl<$Res>
    implements _$WrappedTrackEntryCopyWith<$Res> {
  __$WrappedTrackEntryCopyWithImpl(this._self, this._then);

  final _WrappedTrackEntry _self;
  final $Res Function(_WrappedTrackEntry) _then;

/// Create a copy of WrappedTrackEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackId = null,Object? title = null,Object? artistName = null,Object? albumTitle = null,Object? coverUrl = null,Object? playCount = null,Object? totalSeconds = null,}) {
  return _then(_WrappedTrackEntry(
trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,playCount: null == playCount ? _self.playCount : playCount // ignore: cast_nullable_to_non_nullable
as int,totalSeconds: null == totalSeconds ? _self.totalSeconds : totalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WrappedArtistEntry {

@JsonKey(defaultValue: '') String get name;@JsonKey(defaultValue: 0) int get playCount;@JsonKey(defaultValue: 0) int get totalSeconds; String? get coverUrl;
/// Create a copy of WrappedArtistEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedArtistEntryCopyWith<WrappedArtistEntry> get copyWith => _$WrappedArtistEntryCopyWithImpl<WrappedArtistEntry>(this as WrappedArtistEntry, _$identity);

  /// Serializes this WrappedArtistEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WrappedArtistEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedArtistEntry&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.playCount, _this.playCount) || other.playCount == _this.playCount)&&(identical(other.totalSeconds, _this.totalSeconds) || other.totalSeconds == _this.totalSeconds)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WrappedArtistEntry;
  return Object.hash(runtimeType,_this.name,_this.playCount,_this.totalSeconds,_this.coverUrl);
}

@override
String toString() {
  final _this = this as WrappedArtistEntry;
  return 'WrappedArtistEntry(name: ${_this.name}, playCount: ${_this.playCount}, totalSeconds: ${_this.totalSeconds}, coverUrl: ${_this.coverUrl})';
}


}

/// @nodoc
abstract mixin class $WrappedArtistEntryCopyWith<$Res>  {
  factory $WrappedArtistEntryCopyWith(WrappedArtistEntry value, $Res Function(WrappedArtistEntry) _then) = _$WrappedArtistEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: '') String name,@JsonKey(defaultValue: 0) int playCount,@JsonKey(defaultValue: 0) int totalSeconds, String? coverUrl
});




}
/// @nodoc
class _$WrappedArtistEntryCopyWithImpl<$Res>
    implements $WrappedArtistEntryCopyWith<$Res> {
  _$WrappedArtistEntryCopyWithImpl(this._self, this._then);

  final WrappedArtistEntry _self;
  final $Res Function(WrappedArtistEntry) _then;

/// Create a copy of WrappedArtistEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? playCount = null,Object? totalSeconds = null,Object? coverUrl = freezed,}) {
  return _then(WrappedArtistEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,playCount: null == playCount ? _self.playCount : playCount // ignore: cast_nullable_to_non_nullable
as int,totalSeconds: null == totalSeconds ? _self.totalSeconds : totalSeconds // ignore: cast_nullable_to_non_nullable
as int,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WrappedArtistEntry].
extension WrappedArtistEntryPatterns on WrappedArtistEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WrappedArtistEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WrappedArtistEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WrappedArtistEntry value)  $default,){
final _that = this;
switch (_that) {
case _WrappedArtistEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WrappedArtistEntry value)?  $default,){
final _that = this;
switch (_that) {
case _WrappedArtistEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String name, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds,  String? coverUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WrappedArtistEntry() when $default != null:
return $default(_that.name,_that.playCount,_that.totalSeconds,_that.coverUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String name, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds,  String? coverUrl)  $default,) {final _that = this;
switch (_that) {
case _WrappedArtistEntry():
return $default(_that.name,_that.playCount,_that.totalSeconds,_that.coverUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(defaultValue: '')  String name, @JsonKey(defaultValue: 0)  int playCount, @JsonKey(defaultValue: 0)  int totalSeconds,  String? coverUrl)?  $default,) {final _that = this;
switch (_that) {
case _WrappedArtistEntry() when $default != null:
return $default(_that.name,_that.playCount,_that.totalSeconds,_that.coverUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WrappedArtistEntry implements WrappedArtistEntry {
  const _WrappedArtistEntry({@JsonKey(defaultValue: '') required this.name, @JsonKey(defaultValue: 0) required this.playCount, @JsonKey(defaultValue: 0) required this.totalSeconds, this.coverUrl});
  factory _WrappedArtistEntry.fromJson(Map<String, dynamic> json) => _$WrappedArtistEntryFromJson(json);

@override@JsonKey(defaultValue: '') final  String name;
@override@JsonKey(defaultValue: 0) final  int playCount;
@override@JsonKey(defaultValue: 0) final  int totalSeconds;
@override final  String? coverUrl;

/// Create a copy of WrappedArtistEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WrappedArtistEntryCopyWith<_WrappedArtistEntry> get copyWith => __$WrappedArtistEntryCopyWithImpl<_WrappedArtistEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WrappedArtistEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WrappedArtistEntry&&(identical(other.name, name) || other.name == name)&&(identical(other.playCount, playCount) || other.playCount == playCount)&&(identical(other.totalSeconds, totalSeconds) || other.totalSeconds == totalSeconds)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,playCount,totalSeconds,coverUrl);
}

@override
String toString() {
    return 'WrappedArtistEntry(name: $name, playCount: $playCount, totalSeconds: $totalSeconds, coverUrl: $coverUrl)';
}


}

/// @nodoc
abstract mixin class _$WrappedArtistEntryCopyWith<$Res> implements $WrappedArtistEntryCopyWith<$Res> {
  factory _$WrappedArtistEntryCopyWith(_WrappedArtistEntry value, $Res Function(_WrappedArtistEntry) _then) = __$WrappedArtistEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(defaultValue: '') String name,@JsonKey(defaultValue: 0) int playCount,@JsonKey(defaultValue: 0) int totalSeconds, String? coverUrl
});




}
/// @nodoc
class __$WrappedArtistEntryCopyWithImpl<$Res>
    implements _$WrappedArtistEntryCopyWith<$Res> {
  __$WrappedArtistEntryCopyWithImpl(this._self, this._then);

  final _WrappedArtistEntry _self;
  final $Res Function(_WrappedArtistEntry) _then;

/// Create a copy of WrappedArtistEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? playCount = null,Object? totalSeconds = null,Object? coverUrl = freezed,}) {
  return _then(_WrappedArtistEntry(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,playCount: null == playCount ? _self.playCount : playCount // ignore: cast_nullable_to_non_nullable
as int,totalSeconds: null == totalSeconds ? _self.totalSeconds : totalSeconds // ignore: cast_nullable_to_non_nullable
as int,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WrappedFunFact {

@JsonKey(defaultValue: '') String get key;@JsonKey(defaultValue: <String, dynamic>{}) Map<String, dynamic> get data;
/// Create a copy of WrappedFunFact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedFunFactCopyWith<WrappedFunFact> get copyWith => _$WrappedFunFactCopyWithImpl<WrappedFunFact>(this as WrappedFunFact, _$identity);

  /// Serializes this WrappedFunFact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WrappedFunFact;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedFunFact&&(identical(other.key, _this.key) || other.key == _this.key)&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WrappedFunFact;
  return Object.hash(runtimeType,_this.key,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as WrappedFunFact;
  return 'WrappedFunFact(key: ${_this.key}, data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $WrappedFunFactCopyWith<$Res>  {
  factory $WrappedFunFactCopyWith(WrappedFunFact value, $Res Function(WrappedFunFact) _then) = _$WrappedFunFactCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: '') String key,@JsonKey(defaultValue: <String, dynamic>{}) Map<String, dynamic> data
});




}
/// @nodoc
class _$WrappedFunFactCopyWithImpl<$Res>
    implements $WrappedFunFactCopyWith<$Res> {
  _$WrappedFunFactCopyWithImpl(this._self, this._then);

  final WrappedFunFact _self;
  final $Res Function(WrappedFunFact) _then;

/// Create a copy of WrappedFunFact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? data = null,}) {
  return _then(WrappedFunFact(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [WrappedFunFact].
extension WrappedFunFactPatterns on WrappedFunFact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WrappedFunFact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WrappedFunFact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WrappedFunFact value)  $default,){
final _that = this;
switch (_that) {
case _WrappedFunFact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WrappedFunFact value)?  $default,){
final _that = this;
switch (_that) {
case _WrappedFunFact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String key, @JsonKey(defaultValue: <String, dynamic>{})  Map<String, dynamic> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WrappedFunFact() when $default != null:
return $default(_that.key,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String key, @JsonKey(defaultValue: <String, dynamic>{})  Map<String, dynamic> data)  $default,) {final _that = this;
switch (_that) {
case _WrappedFunFact():
return $default(_that.key,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(defaultValue: '')  String key, @JsonKey(defaultValue: <String, dynamic>{})  Map<String, dynamic> data)?  $default,) {final _that = this;
switch (_that) {
case _WrappedFunFact() when $default != null:
return $default(_that.key,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WrappedFunFact implements WrappedFunFact {
  const _WrappedFunFact({@JsonKey(defaultValue: '') required this.key, @JsonKey(defaultValue: <String, dynamic>{}) required  Map<String, dynamic> data}): _data = data;
  factory _WrappedFunFact.fromJson(Map<String, dynamic> json) => _$WrappedFunFactFromJson(json);

@override@JsonKey(defaultValue: '') final  String key;
 final  Map<String, dynamic> _data;
@override@JsonKey(defaultValue: <String, dynamic>{}) Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}


/// Create a copy of WrappedFunFact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WrappedFunFactCopyWith<_WrappedFunFact> get copyWith => __$WrappedFunFactCopyWithImpl<_WrappedFunFact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WrappedFunFactToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WrappedFunFact&&(identical(other.key, key) || other.key == key)&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,key,const DeepCollectionEquality().hash(_data));
}

@override
String toString() {
    return 'WrappedFunFact(key: $key, data: $data)';
}


}

/// @nodoc
abstract mixin class _$WrappedFunFactCopyWith<$Res> implements $WrappedFunFactCopyWith<$Res> {
  factory _$WrappedFunFactCopyWith(_WrappedFunFact value, $Res Function(_WrappedFunFact) _then) = __$WrappedFunFactCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(defaultValue: '') String key,@JsonKey(defaultValue: <String, dynamic>{}) Map<String, dynamic> data
});




}
/// @nodoc
class __$WrappedFunFactCopyWithImpl<$Res>
    implements _$WrappedFunFactCopyWith<$Res> {
  __$WrappedFunFactCopyWithImpl(this._self, this._then);

  final _WrappedFunFact _self;
  final $Res Function(_WrappedFunFact) _then;

/// Create a copy of WrappedFunFact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? data = null,}) {
  return _then(_WrappedFunFact(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$WrappedData {

@JsonKey(defaultValue: 0) int get year;/// 1–12 for a monthly recap; null for the whole year.
@JsonKey(includeIfNull: false) int? get month;/// Days with music in the period, and how many days it has had so far.
 int get activeDays; int get periodDays;/// Minutes in the period before (last month or last year), to compare;
/// null when unknown.
@JsonKey(includeIfNull: false) int? get previousMinutes;@JsonKey(defaultValue: <WrappedTrackEntry>[]) List<WrappedTrackEntry> get topTracks;@JsonKey(defaultValue: <WrappedArtistEntry>[]) List<WrappedArtistEntry> get topArtists;@JsonKey(defaultValue: 0) int get totalMinutesListened;@JsonKey(defaultValue: 0) int get totalTracksPlayed;@JsonKey(defaultValue: 0) int get uniqueTracksCount;@JsonKey(defaultValue: 0) int get uniqueArtistsCount;@JsonKey(defaultValue: 0) int get favoriteHour;@JsonKey(defaultValue: <int, int>{}) Map<int, int> get hourDistribution;@JsonKey(defaultValue: <WrappedFunFact>[]) List<WrappedFunFact> get funFacts;@JsonKey(fromJson: jsonDateOrNow) DateTime get generatedAt;/// True when built from the per-play log (real play counts). False when
/// only first listens were available ("discoveries"), where counts would
/// all be 1 and must not be shown as plays.
@JsonKey(fromJson: jsonIsTrue) bool get basedOnPlays;/// First day with recorded plays in [year], when [basedOnPlays].
@JsonKey(fromJson: jsonDateOrNull, includeIfNull: false) DateTime? get playsSince;
/// Create a copy of WrappedData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedDataCopyWith<WrappedData> get copyWith => _$WrappedDataCopyWithImpl<WrappedData>(this as WrappedData, _$identity);

  /// Serializes this WrappedData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WrappedData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedData&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.month, _this.month) || other.month == _this.month)&&(identical(other.activeDays, _this.activeDays) || other.activeDays == _this.activeDays)&&(identical(other.periodDays, _this.periodDays) || other.periodDays == _this.periodDays)&&(identical(other.previousMinutes, _this.previousMinutes) || other.previousMinutes == _this.previousMinutes)&&const DeepCollectionEquality().equals(other.topTracks, _this.topTracks)&&const DeepCollectionEquality().equals(other.topArtists, _this.topArtists)&&(identical(other.totalMinutesListened, _this.totalMinutesListened) || other.totalMinutesListened == _this.totalMinutesListened)&&(identical(other.totalTracksPlayed, _this.totalTracksPlayed) || other.totalTracksPlayed == _this.totalTracksPlayed)&&(identical(other.uniqueTracksCount, _this.uniqueTracksCount) || other.uniqueTracksCount == _this.uniqueTracksCount)&&(identical(other.uniqueArtistsCount, _this.uniqueArtistsCount) || other.uniqueArtistsCount == _this.uniqueArtistsCount)&&(identical(other.favoriteHour, _this.favoriteHour) || other.favoriteHour == _this.favoriteHour)&&const DeepCollectionEquality().equals(other.hourDistribution, _this.hourDistribution)&&const DeepCollectionEquality().equals(other.funFacts, _this.funFacts)&&(identical(other.generatedAt, _this.generatedAt) || other.generatedAt == _this.generatedAt)&&(identical(other.basedOnPlays, _this.basedOnPlays) || other.basedOnPlays == _this.basedOnPlays)&&(identical(other.playsSince, _this.playsSince) || other.playsSince == _this.playsSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WrappedData;
  return Object.hash(runtimeType,_this.year,_this.month,_this.activeDays,_this.periodDays,_this.previousMinutes,const DeepCollectionEquality().hash(_this.topTracks),const DeepCollectionEquality().hash(_this.topArtists),_this.totalMinutesListened,_this.totalTracksPlayed,_this.uniqueTracksCount,_this.uniqueArtistsCount,_this.favoriteHour,const DeepCollectionEquality().hash(_this.hourDistribution),const DeepCollectionEquality().hash(_this.funFacts),_this.generatedAt,_this.basedOnPlays,_this.playsSince);
}

@override
String toString() {
  final _this = this as WrappedData;
  return 'WrappedData(year: ${_this.year}, month: ${_this.month}, activeDays: ${_this.activeDays}, periodDays: ${_this.periodDays}, previousMinutes: ${_this.previousMinutes}, topTracks: ${_this.topTracks}, topArtists: ${_this.topArtists}, totalMinutesListened: ${_this.totalMinutesListened}, totalTracksPlayed: ${_this.totalTracksPlayed}, uniqueTracksCount: ${_this.uniqueTracksCount}, uniqueArtistsCount: ${_this.uniqueArtistsCount}, favoriteHour: ${_this.favoriteHour}, hourDistribution: ${_this.hourDistribution}, funFacts: ${_this.funFacts}, generatedAt: ${_this.generatedAt}, basedOnPlays: ${_this.basedOnPlays}, playsSince: ${_this.playsSince})';
}


}

/// @nodoc
abstract mixin class $WrappedDataCopyWith<$Res>  {
  factory $WrappedDataCopyWith(WrappedData value, $Res Function(WrappedData) _then) = _$WrappedDataCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: 0) int year,@JsonKey(includeIfNull: false) int? month, int activeDays, int periodDays,@JsonKey(includeIfNull: false) int? previousMinutes,@JsonKey(defaultValue: <WrappedTrackEntry>[]) List<WrappedTrackEntry> topTracks,@JsonKey(defaultValue: <WrappedArtistEntry>[]) List<WrappedArtistEntry> topArtists,@JsonKey(defaultValue: 0) int totalMinutesListened,@JsonKey(defaultValue: 0) int totalTracksPlayed,@JsonKey(defaultValue: 0) int uniqueTracksCount,@JsonKey(defaultValue: 0) int uniqueArtistsCount,@JsonKey(defaultValue: 0) int favoriteHour,@JsonKey(defaultValue: <int, int>{}) Map<int, int> hourDistribution,@JsonKey(defaultValue: <WrappedFunFact>[]) List<WrappedFunFact> funFacts,@JsonKey(fromJson: jsonDateOrNow) DateTime generatedAt,@JsonKey(fromJson: jsonIsTrue) bool basedOnPlays,@JsonKey(fromJson: jsonDateOrNull, includeIfNull: false) DateTime? playsSince
});




}
/// @nodoc
class _$WrappedDataCopyWithImpl<$Res>
    implements $WrappedDataCopyWith<$Res> {
  _$WrappedDataCopyWithImpl(this._self, this._then);

  final WrappedData _self;
  final $Res Function(WrappedData) _then;

/// Create a copy of WrappedData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? month = freezed,Object? activeDays = null,Object? periodDays = null,Object? previousMinutes = freezed,Object? topTracks = null,Object? topArtists = null,Object? totalMinutesListened = null,Object? totalTracksPlayed = null,Object? uniqueTracksCount = null,Object? uniqueArtistsCount = null,Object? favoriteHour = null,Object? hourDistribution = null,Object? funFacts = null,Object? generatedAt = null,Object? basedOnPlays = null,Object? playsSince = freezed,}) {
  return _then(WrappedData(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: freezed == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int?,activeDays: null == activeDays ? _self.activeDays : activeDays // ignore: cast_nullable_to_non_nullable
as int,periodDays: null == periodDays ? _self.periodDays : periodDays // ignore: cast_nullable_to_non_nullable
as int,previousMinutes: freezed == previousMinutes ? _self.previousMinutes : previousMinutes // ignore: cast_nullable_to_non_nullable
as int?,topTracks: null == topTracks ? _self.topTracks : topTracks // ignore: cast_nullable_to_non_nullable
as List<WrappedTrackEntry>,topArtists: null == topArtists ? _self.topArtists : topArtists // ignore: cast_nullable_to_non_nullable
as List<WrappedArtistEntry>,totalMinutesListened: null == totalMinutesListened ? _self.totalMinutesListened : totalMinutesListened // ignore: cast_nullable_to_non_nullable
as int,totalTracksPlayed: null == totalTracksPlayed ? _self.totalTracksPlayed : totalTracksPlayed // ignore: cast_nullable_to_non_nullable
as int,uniqueTracksCount: null == uniqueTracksCount ? _self.uniqueTracksCount : uniqueTracksCount // ignore: cast_nullable_to_non_nullable
as int,uniqueArtistsCount: null == uniqueArtistsCount ? _self.uniqueArtistsCount : uniqueArtistsCount // ignore: cast_nullable_to_non_nullable
as int,favoriteHour: null == favoriteHour ? _self.favoriteHour : favoriteHour // ignore: cast_nullable_to_non_nullable
as int,hourDistribution: null == hourDistribution ? _self.hourDistribution : hourDistribution // ignore: cast_nullable_to_non_nullable
as Map<int, int>,funFacts: null == funFacts ? _self.funFacts : funFacts // ignore: cast_nullable_to_non_nullable
as List<WrappedFunFact>,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,basedOnPlays: null == basedOnPlays ? _self.basedOnPlays : basedOnPlays // ignore: cast_nullable_to_non_nullable
as bool,playsSince: freezed == playsSince ? _self.playsSince : playsSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [WrappedData].
extension WrappedDataPatterns on WrappedData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WrappedData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WrappedData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WrappedData value)  $default,){
final _that = this;
switch (_that) {
case _WrappedData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WrappedData value)?  $default,){
final _that = this;
switch (_that) {
case _WrappedData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: 0)  int year, @JsonKey(includeIfNull: false)  int? month,  int activeDays,  int periodDays, @JsonKey(includeIfNull: false)  int? previousMinutes, @JsonKey(defaultValue: <WrappedTrackEntry>[])  List<WrappedTrackEntry> topTracks, @JsonKey(defaultValue: <WrappedArtistEntry>[])  List<WrappedArtistEntry> topArtists, @JsonKey(defaultValue: 0)  int totalMinutesListened, @JsonKey(defaultValue: 0)  int totalTracksPlayed, @JsonKey(defaultValue: 0)  int uniqueTracksCount, @JsonKey(defaultValue: 0)  int uniqueArtistsCount, @JsonKey(defaultValue: 0)  int favoriteHour, @JsonKey(defaultValue: <int, int>{})  Map<int, int> hourDistribution, @JsonKey(defaultValue: <WrappedFunFact>[])  List<WrappedFunFact> funFacts, @JsonKey(fromJson: jsonDateOrNow)  DateTime generatedAt, @JsonKey(fromJson: jsonIsTrue)  bool basedOnPlays, @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false)  DateTime? playsSince)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WrappedData() when $default != null:
return $default(_that.year,_that.month,_that.activeDays,_that.periodDays,_that.previousMinutes,_that.topTracks,_that.topArtists,_that.totalMinutesListened,_that.totalTracksPlayed,_that.uniqueTracksCount,_that.uniqueArtistsCount,_that.favoriteHour,_that.hourDistribution,_that.funFacts,_that.generatedAt,_that.basedOnPlays,_that.playsSince);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: 0)  int year, @JsonKey(includeIfNull: false)  int? month,  int activeDays,  int periodDays, @JsonKey(includeIfNull: false)  int? previousMinutes, @JsonKey(defaultValue: <WrappedTrackEntry>[])  List<WrappedTrackEntry> topTracks, @JsonKey(defaultValue: <WrappedArtistEntry>[])  List<WrappedArtistEntry> topArtists, @JsonKey(defaultValue: 0)  int totalMinutesListened, @JsonKey(defaultValue: 0)  int totalTracksPlayed, @JsonKey(defaultValue: 0)  int uniqueTracksCount, @JsonKey(defaultValue: 0)  int uniqueArtistsCount, @JsonKey(defaultValue: 0)  int favoriteHour, @JsonKey(defaultValue: <int, int>{})  Map<int, int> hourDistribution, @JsonKey(defaultValue: <WrappedFunFact>[])  List<WrappedFunFact> funFacts, @JsonKey(fromJson: jsonDateOrNow)  DateTime generatedAt, @JsonKey(fromJson: jsonIsTrue)  bool basedOnPlays, @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false)  DateTime? playsSince)  $default,) {final _that = this;
switch (_that) {
case _WrappedData():
return $default(_that.year,_that.month,_that.activeDays,_that.periodDays,_that.previousMinutes,_that.topTracks,_that.topArtists,_that.totalMinutesListened,_that.totalTracksPlayed,_that.uniqueTracksCount,_that.uniqueArtistsCount,_that.favoriteHour,_that.hourDistribution,_that.funFacts,_that.generatedAt,_that.basedOnPlays,_that.playsSince);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(defaultValue: 0)  int year, @JsonKey(includeIfNull: false)  int? month,  int activeDays,  int periodDays, @JsonKey(includeIfNull: false)  int? previousMinutes, @JsonKey(defaultValue: <WrappedTrackEntry>[])  List<WrappedTrackEntry> topTracks, @JsonKey(defaultValue: <WrappedArtistEntry>[])  List<WrappedArtistEntry> topArtists, @JsonKey(defaultValue: 0)  int totalMinutesListened, @JsonKey(defaultValue: 0)  int totalTracksPlayed, @JsonKey(defaultValue: 0)  int uniqueTracksCount, @JsonKey(defaultValue: 0)  int uniqueArtistsCount, @JsonKey(defaultValue: 0)  int favoriteHour, @JsonKey(defaultValue: <int, int>{})  Map<int, int> hourDistribution, @JsonKey(defaultValue: <WrappedFunFact>[])  List<WrappedFunFact> funFacts, @JsonKey(fromJson: jsonDateOrNow)  DateTime generatedAt, @JsonKey(fromJson: jsonIsTrue)  bool basedOnPlays, @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false)  DateTime? playsSince)?  $default,) {final _that = this;
switch (_that) {
case _WrappedData() when $default != null:
return $default(_that.year,_that.month,_that.activeDays,_that.periodDays,_that.previousMinutes,_that.topTracks,_that.topArtists,_that.totalMinutesListened,_that.totalTracksPlayed,_that.uniqueTracksCount,_that.uniqueArtistsCount,_that.favoriteHour,_that.hourDistribution,_that.funFacts,_that.generatedAt,_that.basedOnPlays,_that.playsSince);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WrappedData extends WrappedData {
  const _WrappedData({@JsonKey(defaultValue: 0) required this.year, @JsonKey(includeIfNull: false) this.month, this.activeDays = 0, this.periodDays = 0, @JsonKey(includeIfNull: false) this.previousMinutes, @JsonKey(defaultValue: <WrappedTrackEntry>[]) required  List<WrappedTrackEntry> topTracks, @JsonKey(defaultValue: <WrappedArtistEntry>[]) required  List<WrappedArtistEntry> topArtists, @JsonKey(defaultValue: 0) required this.totalMinutesListened, @JsonKey(defaultValue: 0) required this.totalTracksPlayed, @JsonKey(defaultValue: 0) required this.uniqueTracksCount, @JsonKey(defaultValue: 0) required this.uniqueArtistsCount, @JsonKey(defaultValue: 0) required this.favoriteHour, @JsonKey(defaultValue: <int, int>{}) required  Map<int, int> hourDistribution, @JsonKey(defaultValue: <WrappedFunFact>[]) required  List<WrappedFunFact> funFacts, @JsonKey(fromJson: jsonDateOrNow) required this.generatedAt, @JsonKey(fromJson: jsonIsTrue) this.basedOnPlays = false, @JsonKey(fromJson: jsonDateOrNull, includeIfNull: false) this.playsSince}): _topTracks = topTracks,_topArtists = topArtists,_hourDistribution = hourDistribution,_funFacts = funFacts,super._();
  factory _WrappedData.fromJson(Map<String, dynamic> json) => _$WrappedDataFromJson(json);

@override@JsonKey(defaultValue: 0) final  int year;
/// 1–12 for a monthly recap; null for the whole year.
@override@JsonKey(includeIfNull: false) final  int? month;
/// Days with music in the period, and how many days it has had so far.
@override@JsonKey() final  int activeDays;
@override@JsonKey() final  int periodDays;
/// Minutes in the period before (last month or last year), to compare;
/// null when unknown.
@override@JsonKey(includeIfNull: false) final  int? previousMinutes;
 final  List<WrappedTrackEntry> _topTracks;
@override@JsonKey(defaultValue: <WrappedTrackEntry>[]) List<WrappedTrackEntry> get topTracks {
  if (_topTracks is EqualUnmodifiableListView) return _topTracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topTracks);
}

 final  List<WrappedArtistEntry> _topArtists;
@override@JsonKey(defaultValue: <WrappedArtistEntry>[]) List<WrappedArtistEntry> get topArtists {
  if (_topArtists is EqualUnmodifiableListView) return _topArtists;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topArtists);
}

@override@JsonKey(defaultValue: 0) final  int totalMinutesListened;
@override@JsonKey(defaultValue: 0) final  int totalTracksPlayed;
@override@JsonKey(defaultValue: 0) final  int uniqueTracksCount;
@override@JsonKey(defaultValue: 0) final  int uniqueArtistsCount;
@override@JsonKey(defaultValue: 0) final  int favoriteHour;
 final  Map<int, int> _hourDistribution;
@override@JsonKey(defaultValue: <int, int>{}) Map<int, int> get hourDistribution {
  if (_hourDistribution is EqualUnmodifiableMapView) return _hourDistribution;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_hourDistribution);
}

 final  List<WrappedFunFact> _funFacts;
@override@JsonKey(defaultValue: <WrappedFunFact>[]) List<WrappedFunFact> get funFacts {
  if (_funFacts is EqualUnmodifiableListView) return _funFacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_funFacts);
}

@override@JsonKey(fromJson: jsonDateOrNow) final  DateTime generatedAt;
/// True when built from the per-play log (real play counts). False when
/// only first listens were available ("discoveries"), where counts would
/// all be 1 and must not be shown as plays.
@override@JsonKey(fromJson: jsonIsTrue) final  bool basedOnPlays;
/// First day with recorded plays in [year], when [basedOnPlays].
@override@JsonKey(fromJson: jsonDateOrNull, includeIfNull: false) final  DateTime? playsSince;

/// Create a copy of WrappedData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WrappedDataCopyWith<_WrappedData> get copyWith => __$WrappedDataCopyWithImpl<_WrappedData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WrappedDataToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WrappedData&&(identical(other.year, year) || other.year == year)&&(identical(other.month, month) || other.month == month)&&(identical(other.activeDays, activeDays) || other.activeDays == activeDays)&&(identical(other.periodDays, periodDays) || other.periodDays == periodDays)&&(identical(other.previousMinutes, previousMinutes) || other.previousMinutes == previousMinutes)&&const DeepCollectionEquality().equals(other.topTracks, _topTracks)&&const DeepCollectionEquality().equals(other.topArtists, _topArtists)&&(identical(other.totalMinutesListened, totalMinutesListened) || other.totalMinutesListened == totalMinutesListened)&&(identical(other.totalTracksPlayed, totalTracksPlayed) || other.totalTracksPlayed == totalTracksPlayed)&&(identical(other.uniqueTracksCount, uniqueTracksCount) || other.uniqueTracksCount == uniqueTracksCount)&&(identical(other.uniqueArtistsCount, uniqueArtistsCount) || other.uniqueArtistsCount == uniqueArtistsCount)&&(identical(other.favoriteHour, favoriteHour) || other.favoriteHour == favoriteHour)&&const DeepCollectionEquality().equals(other.hourDistribution, _hourDistribution)&&const DeepCollectionEquality().equals(other.funFacts, _funFacts)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt)&&(identical(other.basedOnPlays, basedOnPlays) || other.basedOnPlays == basedOnPlays)&&(identical(other.playsSince, playsSince) || other.playsSince == playsSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,year,month,activeDays,periodDays,previousMinutes,const DeepCollectionEquality().hash(_topTracks),const DeepCollectionEquality().hash(_topArtists),totalMinutesListened,totalTracksPlayed,uniqueTracksCount,uniqueArtistsCount,favoriteHour,const DeepCollectionEquality().hash(_hourDistribution),const DeepCollectionEquality().hash(_funFacts),generatedAt,basedOnPlays,playsSince);
}

@override
String toString() {
    return 'WrappedData(year: $year, month: $month, activeDays: $activeDays, periodDays: $periodDays, previousMinutes: $previousMinutes, topTracks: $topTracks, topArtists: $topArtists, totalMinutesListened: $totalMinutesListened, totalTracksPlayed: $totalTracksPlayed, uniqueTracksCount: $uniqueTracksCount, uniqueArtistsCount: $uniqueArtistsCount, favoriteHour: $favoriteHour, hourDistribution: $hourDistribution, funFacts: $funFacts, generatedAt: $generatedAt, basedOnPlays: $basedOnPlays, playsSince: $playsSince)';
}


}

/// @nodoc
abstract mixin class _$WrappedDataCopyWith<$Res> implements $WrappedDataCopyWith<$Res> {
  factory _$WrappedDataCopyWith(_WrappedData value, $Res Function(_WrappedData) _then) = __$WrappedDataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(defaultValue: 0) int year,@JsonKey(includeIfNull: false) int? month, int activeDays, int periodDays,@JsonKey(includeIfNull: false) int? previousMinutes,@JsonKey(defaultValue: <WrappedTrackEntry>[]) List<WrappedTrackEntry> topTracks,@JsonKey(defaultValue: <WrappedArtistEntry>[]) List<WrappedArtistEntry> topArtists,@JsonKey(defaultValue: 0) int totalMinutesListened,@JsonKey(defaultValue: 0) int totalTracksPlayed,@JsonKey(defaultValue: 0) int uniqueTracksCount,@JsonKey(defaultValue: 0) int uniqueArtistsCount,@JsonKey(defaultValue: 0) int favoriteHour,@JsonKey(defaultValue: <int, int>{}) Map<int, int> hourDistribution,@JsonKey(defaultValue: <WrappedFunFact>[]) List<WrappedFunFact> funFacts,@JsonKey(fromJson: jsonDateOrNow) DateTime generatedAt,@JsonKey(fromJson: jsonIsTrue) bool basedOnPlays,@JsonKey(fromJson: jsonDateOrNull, includeIfNull: false) DateTime? playsSince
});




}
/// @nodoc
class __$WrappedDataCopyWithImpl<$Res>
    implements _$WrappedDataCopyWith<$Res> {
  __$WrappedDataCopyWithImpl(this._self, this._then);

  final _WrappedData _self;
  final $Res Function(_WrappedData) _then;

/// Create a copy of WrappedData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? month = freezed,Object? activeDays = null,Object? periodDays = null,Object? previousMinutes = freezed,Object? topTracks = null,Object? topArtists = null,Object? totalMinutesListened = null,Object? totalTracksPlayed = null,Object? uniqueTracksCount = null,Object? uniqueArtistsCount = null,Object? favoriteHour = null,Object? hourDistribution = null,Object? funFacts = null,Object? generatedAt = null,Object? basedOnPlays = null,Object? playsSince = freezed,}) {
  return _then(_WrappedData(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: freezed == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int?,activeDays: null == activeDays ? _self.activeDays : activeDays // ignore: cast_nullable_to_non_nullable
as int,periodDays: null == periodDays ? _self.periodDays : periodDays // ignore: cast_nullable_to_non_nullable
as int,previousMinutes: freezed == previousMinutes ? _self.previousMinutes : previousMinutes // ignore: cast_nullable_to_non_nullable
as int?,topTracks: null == topTracks ? _self._topTracks : topTracks // ignore: cast_nullable_to_non_nullable
as List<WrappedTrackEntry>,topArtists: null == topArtists ? _self._topArtists : topArtists // ignore: cast_nullable_to_non_nullable
as List<WrappedArtistEntry>,totalMinutesListened: null == totalMinutesListened ? _self.totalMinutesListened : totalMinutesListened // ignore: cast_nullable_to_non_nullable
as int,totalTracksPlayed: null == totalTracksPlayed ? _self.totalTracksPlayed : totalTracksPlayed // ignore: cast_nullable_to_non_nullable
as int,uniqueTracksCount: null == uniqueTracksCount ? _self.uniqueTracksCount : uniqueTracksCount // ignore: cast_nullable_to_non_nullable
as int,uniqueArtistsCount: null == uniqueArtistsCount ? _self.uniqueArtistsCount : uniqueArtistsCount // ignore: cast_nullable_to_non_nullable
as int,favoriteHour: null == favoriteHour ? _self.favoriteHour : favoriteHour // ignore: cast_nullable_to_non_nullable
as int,hourDistribution: null == hourDistribution ? _self._hourDistribution : hourDistribution // ignore: cast_nullable_to_non_nullable
as Map<int, int>,funFacts: null == funFacts ? _self._funFacts : funFacts // ignore: cast_nullable_to_non_nullable
as List<WrappedFunFact>,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,basedOnPlays: null == basedOnPlays ? _self.basedOnPlays : basedOnPlays // ignore: cast_nullable_to_non_nullable
as bool,playsSince: freezed == playsSince ? _self.playsSince : playsSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
