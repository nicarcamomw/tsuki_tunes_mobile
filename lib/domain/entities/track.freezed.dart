// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Contributor {

@JsonKey(fromJson: jsonString) String get id;@JsonKey(defaultValue: '') String get name; String? get role;
/// Create a copy of Contributor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContributorCopyWith<Contributor> get copyWith => _$ContributorCopyWithImpl<Contributor>(this as Contributor, _$identity);

  /// Serializes this Contributor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Contributor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contributor&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.role, _this.role) || other.role == _this.role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Contributor;
  return Object.hash(runtimeType,_this.id,_this.name,_this.role);
}

@override
String toString() {
  final _this = this as Contributor;
  return 'Contributor(id: ${_this.id}, name: ${_this.name}, role: ${_this.role})';
}


}

/// @nodoc
abstract mixin class $ContributorCopyWith<$Res>  {
  factory $ContributorCopyWith(Contributor value, $Res Function(Contributor) _then) = _$ContributorCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: '') String name, String? role
});




}
/// @nodoc
class _$ContributorCopyWithImpl<$Res>
    implements $ContributorCopyWith<$Res> {
  _$ContributorCopyWithImpl(this._self, this._then);

  final Contributor _self;
  final $Res Function(Contributor) _then;

/// Create a copy of Contributor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? role = freezed,}) {
  return _then(Contributor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Contributor].
extension ContributorPatterns on Contributor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contributor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contributor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contributor value)  $default,){
final _that = this;
switch (_that) {
case _Contributor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contributor value)?  $default,){
final _that = this;
switch (_that) {
case _Contributor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: '')  String name,  String? role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contributor() when $default != null:
return $default(_that.id,_that.name,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: '')  String name,  String? role)  $default,) {final _that = this;
switch (_that) {
case _Contributor():
return $default(_that.id,_that.name,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: '')  String name,  String? role)?  $default,) {final _that = this;
switch (_that) {
case _Contributor() when $default != null:
return $default(_that.id,_that.name,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Contributor implements Contributor {
  const _Contributor({@JsonKey(fromJson: jsonString) required this.id, @JsonKey(defaultValue: '') required this.name, this.role});
  factory _Contributor.fromJson(Map<String, dynamic> json) => _$ContributorFromJson(json);

@override@JsonKey(fromJson: jsonString) final  String id;
@override@JsonKey(defaultValue: '') final  String name;
@override final  String? role;

/// Create a copy of Contributor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContributorCopyWith<_Contributor> get copyWith => __$ContributorCopyWithImpl<_Contributor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContributorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contributor&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,role);
}

@override
String toString() {
    return 'Contributor(id: $id, name: $name, role: $role)';
}


}

/// @nodoc
abstract mixin class _$ContributorCopyWith<$Res> implements $ContributorCopyWith<$Res> {
  factory _$ContributorCopyWith(_Contributor value, $Res Function(_Contributor) _then) = __$ContributorCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: '') String name, String? role
});




}
/// @nodoc
class __$ContributorCopyWithImpl<$Res>
    implements _$ContributorCopyWith<$Res> {
  __$ContributorCopyWithImpl(this._self, this._then);

  final _Contributor _self;
  final $Res Function(_Contributor) _then;

/// Create a copy of Contributor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? role = freezed,}) {
  return _then(_Contributor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Track {

@JsonKey(fromJson: jsonString) String get id;@JsonKey(defaultValue: 'Unknown Track') String get title;@JsonKey(fromJson: jsonString) String get artistId;@JsonKey(defaultValue: 'Unknown Artist') String get artistName;@JsonKey(fromJson: jsonString) String get albumId;@JsonKey(defaultValue: '') String get albumTitle;@JsonKey(defaultValue: '') String get coverUrl;@JsonKey(defaultValue: '') String get previewUrl;@JsonKey(defaultValue: 30) int get durationSeconds; int? get rank;@JsonKey(fromJson: jsonIsTrue) bool get isExplicit; List<Contributor> get contributors; String? get link;@JsonKey(fromJson: jsonStringOrNull) String? get isrc;
/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackCopyWith<Track> get copyWith => _$TrackCopyWithImpl<Track>(this as Track, _$identity);

  /// Serializes this Track to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Track;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Track&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.artistId, _this.artistId) || other.artistId == _this.artistId)&&(identical(other.artistName, _this.artistName) || other.artistName == _this.artistName)&&(identical(other.albumId, _this.albumId) || other.albumId == _this.albumId)&&(identical(other.albumTitle, _this.albumTitle) || other.albumTitle == _this.albumTitle)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.previewUrl, _this.previewUrl) || other.previewUrl == _this.previewUrl)&&(identical(other.durationSeconds, _this.durationSeconds) || other.durationSeconds == _this.durationSeconds)&&(identical(other.rank, _this.rank) || other.rank == _this.rank)&&(identical(other.isExplicit, _this.isExplicit) || other.isExplicit == _this.isExplicit)&&const DeepCollectionEquality().equals(other.contributors, _this.contributors)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.isrc, _this.isrc) || other.isrc == _this.isrc));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Track;
  return Object.hash(runtimeType,_this.id,_this.title,_this.artistId,_this.artistName,_this.albumId,_this.albumTitle,_this.coverUrl,_this.previewUrl,_this.durationSeconds,_this.rank,_this.isExplicit,const DeepCollectionEquality().hash(_this.contributors),_this.link,_this.isrc);
}

@override
String toString() {
  final _this = this as Track;
  return 'Track(id: ${_this.id}, title: ${_this.title}, artistId: ${_this.artistId}, artistName: ${_this.artistName}, albumId: ${_this.albumId}, albumTitle: ${_this.albumTitle}, coverUrl: ${_this.coverUrl}, previewUrl: ${_this.previewUrl}, durationSeconds: ${_this.durationSeconds}, rank: ${_this.rank}, isExplicit: ${_this.isExplicit}, contributors: ${_this.contributors}, link: ${_this.link}, isrc: ${_this.isrc})';
}


}

/// @nodoc
abstract mixin class $TrackCopyWith<$Res>  {
  factory $TrackCopyWith(Track value, $Res Function(Track) _then) = _$TrackCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Track') String title,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: 'Unknown Artist') String artistName,@JsonKey(fromJson: jsonString) String albumId,@JsonKey(defaultValue: '') String albumTitle,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: '') String previewUrl,@JsonKey(defaultValue: 30) int durationSeconds, int? rank,@JsonKey(fromJson: jsonIsTrue) bool isExplicit, List<Contributor> contributors, String? link,@JsonKey(fromJson: jsonStringOrNull) String? isrc
});




}
/// @nodoc
class _$TrackCopyWithImpl<$Res>
    implements $TrackCopyWith<$Res> {
  _$TrackCopyWithImpl(this._self, this._then);

  final Track _self;
  final $Res Function(Track) _then;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? artistId = null,Object? artistName = null,Object? albumId = null,Object? albumTitle = null,Object? coverUrl = null,Object? previewUrl = null,Object? durationSeconds = null,Object? rank = freezed,Object? isExplicit = null,Object? contributors = null,Object? link = freezed,Object? isrc = freezed,}) {
  return _then(Track(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as String,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,previewUrl: null == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,isExplicit: null == isExplicit ? _self.isExplicit : isExplicit // ignore: cast_nullable_to_non_nullable
as bool,contributors: null == contributors ? _self.contributors : contributors // ignore: cast_nullable_to_non_nullable
as List<Contributor>,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,isrc: freezed == isrc ? _self.isrc : isrc // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Track].
extension TrackPatterns on Track {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Track value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Track() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Track value)  $default,){
final _that = this;
switch (_that) {
case _Track():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Track value)?  $default,){
final _that = this;
switch (_that) {
case _Track() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Track')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName, @JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String previewUrl, @JsonKey(defaultValue: 30)  int durationSeconds,  int? rank, @JsonKey(fromJson: jsonIsTrue)  bool isExplicit,  List<Contributor> contributors,  String? link, @JsonKey(fromJson: jsonStringOrNull)  String? isrc)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that.id,_that.title,_that.artistId,_that.artistName,_that.albumId,_that.albumTitle,_that.coverUrl,_that.previewUrl,_that.durationSeconds,_that.rank,_that.isExplicit,_that.contributors,_that.link,_that.isrc);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Track')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName, @JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String previewUrl, @JsonKey(defaultValue: 30)  int durationSeconds,  int? rank, @JsonKey(fromJson: jsonIsTrue)  bool isExplicit,  List<Contributor> contributors,  String? link, @JsonKey(fromJson: jsonStringOrNull)  String? isrc)  $default,) {final _that = this;
switch (_that) {
case _Track():
return $default(_that.id,_that.title,_that.artistId,_that.artistName,_that.albumId,_that.albumTitle,_that.coverUrl,_that.previewUrl,_that.durationSeconds,_that.rank,_that.isExplicit,_that.contributors,_that.link,_that.isrc);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Track')  String title, @JsonKey(fromJson: jsonString)  String artistId, @JsonKey(defaultValue: 'Unknown Artist')  String artistName, @JsonKey(fromJson: jsonString)  String albumId, @JsonKey(defaultValue: '')  String albumTitle, @JsonKey(defaultValue: '')  String coverUrl, @JsonKey(defaultValue: '')  String previewUrl, @JsonKey(defaultValue: 30)  int durationSeconds,  int? rank, @JsonKey(fromJson: jsonIsTrue)  bool isExplicit,  List<Contributor> contributors,  String? link, @JsonKey(fromJson: jsonStringOrNull)  String? isrc)?  $default,) {final _that = this;
switch (_that) {
case _Track() when $default != null:
return $default(_that.id,_that.title,_that.artistId,_that.artistName,_that.albumId,_that.albumTitle,_that.coverUrl,_that.previewUrl,_that.durationSeconds,_that.rank,_that.isExplicit,_that.contributors,_that.link,_that.isrc);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Track extends Track {
  const _Track({@JsonKey(fromJson: jsonString) required this.id, @JsonKey(defaultValue: 'Unknown Track') required this.title, @JsonKey(fromJson: jsonString) required this.artistId, @JsonKey(defaultValue: 'Unknown Artist') required this.artistName, @JsonKey(fromJson: jsonString) required this.albumId, @JsonKey(defaultValue: '') required this.albumTitle, @JsonKey(defaultValue: '') required this.coverUrl, @JsonKey(defaultValue: '') required this.previewUrl, @JsonKey(defaultValue: 30) required this.durationSeconds, this.rank, @JsonKey(fromJson: jsonIsTrue) this.isExplicit = false,  List<Contributor> contributors = const [], this.link, @JsonKey(fromJson: jsonStringOrNull) this.isrc}): _contributors = contributors,super._();
  factory _Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

@override@JsonKey(fromJson: jsonString) final  String id;
@override@JsonKey(defaultValue: 'Unknown Track') final  String title;
@override@JsonKey(fromJson: jsonString) final  String artistId;
@override@JsonKey(defaultValue: 'Unknown Artist') final  String artistName;
@override@JsonKey(fromJson: jsonString) final  String albumId;
@override@JsonKey(defaultValue: '') final  String albumTitle;
@override@JsonKey(defaultValue: '') final  String coverUrl;
@override@JsonKey(defaultValue: '') final  String previewUrl;
@override@JsonKey(defaultValue: 30) final  int durationSeconds;
@override final  int? rank;
@override@JsonKey(fromJson: jsonIsTrue) final  bool isExplicit;
 final  List<Contributor> _contributors;
@override@JsonKey() List<Contributor> get contributors {
  if (_contributors is EqualUnmodifiableListView) return _contributors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contributors);
}

@override final  String? link;
@override@JsonKey(fromJson: jsonStringOrNull) final  String? isrc;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackCopyWith<_Track> get copyWith => __$TrackCopyWithImpl<_Track>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Track&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.albumId, albumId) || other.albumId == albumId)&&(identical(other.albumTitle, albumTitle) || other.albumTitle == albumTitle)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.previewUrl, previewUrl) || other.previewUrl == previewUrl)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.isExplicit, isExplicit) || other.isExplicit == isExplicit)&&const DeepCollectionEquality().equals(other.contributors, _contributors)&&(identical(other.link, link) || other.link == link)&&(identical(other.isrc, isrc) || other.isrc == isrc));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,artistId,artistName,albumId,albumTitle,coverUrl,previewUrl,durationSeconds,rank,isExplicit,const DeepCollectionEquality().hash(_contributors),link,isrc);
}

@override
String toString() {
    return 'Track(id: $id, title: $title, artistId: $artistId, artistName: $artistName, albumId: $albumId, albumTitle: $albumTitle, coverUrl: $coverUrl, previewUrl: $previewUrl, durationSeconds: $durationSeconds, rank: $rank, isExplicit: $isExplicit, contributors: $contributors, link: $link, isrc: $isrc)';
}


}

/// @nodoc
abstract mixin class _$TrackCopyWith<$Res> implements $TrackCopyWith<$Res> {
  factory _$TrackCopyWith(_Track value, $Res Function(_Track) _then) = __$TrackCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Track') String title,@JsonKey(fromJson: jsonString) String artistId,@JsonKey(defaultValue: 'Unknown Artist') String artistName,@JsonKey(fromJson: jsonString) String albumId,@JsonKey(defaultValue: '') String albumTitle,@JsonKey(defaultValue: '') String coverUrl,@JsonKey(defaultValue: '') String previewUrl,@JsonKey(defaultValue: 30) int durationSeconds, int? rank,@JsonKey(fromJson: jsonIsTrue) bool isExplicit, List<Contributor> contributors, String? link,@JsonKey(fromJson: jsonStringOrNull) String? isrc
});




}
/// @nodoc
class __$TrackCopyWithImpl<$Res>
    implements _$TrackCopyWith<$Res> {
  __$TrackCopyWithImpl(this._self, this._then);

  final _Track _self;
  final $Res Function(_Track) _then;

/// Create a copy of Track
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? artistId = null,Object? artistName = null,Object? albumId = null,Object? albumTitle = null,Object? coverUrl = null,Object? previewUrl = null,Object? durationSeconds = null,Object? rank = freezed,Object? isExplicit = null,Object? contributors = null,Object? link = freezed,Object? isrc = freezed,}) {
  return _then(_Track(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,albumId: null == albumId ? _self.albumId : albumId // ignore: cast_nullable_to_non_nullable
as String,albumTitle: null == albumTitle ? _self.albumTitle : albumTitle // ignore: cast_nullable_to_non_nullable
as String,coverUrl: null == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String,previewUrl: null == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,rank: freezed == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int?,isExplicit: null == isExplicit ? _self.isExplicit : isExplicit // ignore: cast_nullable_to_non_nullable
as bool,contributors: null == contributors ? _self._contributors : contributors // ignore: cast_nullable_to_non_nullable
as List<Contributor>,link: freezed == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String?,isrc: freezed == isrc ? _self.isrc : isrc // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
