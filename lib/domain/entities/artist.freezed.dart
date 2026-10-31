// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'artist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Artist {

@JsonKey(fromJson: jsonString) String get id;@JsonKey(defaultValue: 'Unknown Artist') String get name;@JsonKey(defaultValue: '') String get pictureUrl; String? get pictureSmall; String? get pictureMedium; String? get pictureBig; String? get pictureXl; int get fansCount; int get albumsCount;
/// Create a copy of Artist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtistCopyWith<Artist> get copyWith => _$ArtistCopyWithImpl<Artist>(this as Artist, _$identity);

  /// Serializes this Artist to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Artist;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Artist&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.pictureUrl, _this.pictureUrl) || other.pictureUrl == _this.pictureUrl)&&(identical(other.pictureSmall, _this.pictureSmall) || other.pictureSmall == _this.pictureSmall)&&(identical(other.pictureMedium, _this.pictureMedium) || other.pictureMedium == _this.pictureMedium)&&(identical(other.pictureBig, _this.pictureBig) || other.pictureBig == _this.pictureBig)&&(identical(other.pictureXl, _this.pictureXl) || other.pictureXl == _this.pictureXl)&&(identical(other.fansCount, _this.fansCount) || other.fansCount == _this.fansCount)&&(identical(other.albumsCount, _this.albumsCount) || other.albumsCount == _this.albumsCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Artist;
  return Object.hash(runtimeType,_this.id,_this.name,_this.pictureUrl,_this.pictureSmall,_this.pictureMedium,_this.pictureBig,_this.pictureXl,_this.fansCount,_this.albumsCount);
}

@override
String toString() {
  final _this = this as Artist;
  return 'Artist(id: ${_this.id}, name: ${_this.name}, pictureUrl: ${_this.pictureUrl}, pictureSmall: ${_this.pictureSmall}, pictureMedium: ${_this.pictureMedium}, pictureBig: ${_this.pictureBig}, pictureXl: ${_this.pictureXl}, fansCount: ${_this.fansCount}, albumsCount: ${_this.albumsCount})';
}


}

/// @nodoc
abstract mixin class $ArtistCopyWith<$Res>  {
  factory $ArtistCopyWith(Artist value, $Res Function(Artist) _then) = _$ArtistCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Artist') String name,@JsonKey(defaultValue: '') String pictureUrl, String? pictureSmall, String? pictureMedium, String? pictureBig, String? pictureXl, int fansCount, int albumsCount
});




}
/// @nodoc
class _$ArtistCopyWithImpl<$Res>
    implements $ArtistCopyWith<$Res> {
  _$ArtistCopyWithImpl(this._self, this._then);

  final Artist _self;
  final $Res Function(Artist) _then;

/// Create a copy of Artist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? pictureUrl = null,Object? pictureSmall = freezed,Object? pictureMedium = freezed,Object? pictureBig = freezed,Object? pictureXl = freezed,Object? fansCount = null,Object? albumsCount = null,}) {
  return _then(Artist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pictureUrl: null == pictureUrl ? _self.pictureUrl : pictureUrl // ignore: cast_nullable_to_non_nullable
as String,pictureSmall: freezed == pictureSmall ? _self.pictureSmall : pictureSmall // ignore: cast_nullable_to_non_nullable
as String?,pictureMedium: freezed == pictureMedium ? _self.pictureMedium : pictureMedium // ignore: cast_nullable_to_non_nullable
as String?,pictureBig: freezed == pictureBig ? _self.pictureBig : pictureBig // ignore: cast_nullable_to_non_nullable
as String?,pictureXl: freezed == pictureXl ? _self.pictureXl : pictureXl // ignore: cast_nullable_to_non_nullable
as String?,fansCount: null == fansCount ? _self.fansCount : fansCount // ignore: cast_nullable_to_non_nullable
as int,albumsCount: null == albumsCount ? _self.albumsCount : albumsCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Artist].
extension ArtistPatterns on Artist {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Artist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Artist() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Artist value)  $default,){
final _that = this;
switch (_that) {
case _Artist():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Artist value)?  $default,){
final _that = this;
switch (_that) {
case _Artist() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Artist')  String name, @JsonKey(defaultValue: '')  String pictureUrl,  String? pictureSmall,  String? pictureMedium,  String? pictureBig,  String? pictureXl,  int fansCount,  int albumsCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Artist() when $default != null:
return $default(_that.id,_that.name,_that.pictureUrl,_that.pictureSmall,_that.pictureMedium,_that.pictureBig,_that.pictureXl,_that.fansCount,_that.albumsCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Artist')  String name, @JsonKey(defaultValue: '')  String pictureUrl,  String? pictureSmall,  String? pictureMedium,  String? pictureBig,  String? pictureXl,  int fansCount,  int albumsCount)  $default,) {final _that = this;
switch (_that) {
case _Artist():
return $default(_that.id,_that.name,_that.pictureUrl,_that.pictureSmall,_that.pictureMedium,_that.pictureBig,_that.pictureXl,_that.fansCount,_that.albumsCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonString)  String id, @JsonKey(defaultValue: 'Unknown Artist')  String name, @JsonKey(defaultValue: '')  String pictureUrl,  String? pictureSmall,  String? pictureMedium,  String? pictureBig,  String? pictureXl,  int fansCount,  int albumsCount)?  $default,) {final _that = this;
switch (_that) {
case _Artist() when $default != null:
return $default(_that.id,_that.name,_that.pictureUrl,_that.pictureSmall,_that.pictureMedium,_that.pictureBig,_that.pictureXl,_that.fansCount,_that.albumsCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Artist extends Artist {
  const _Artist({@JsonKey(fromJson: jsonString) required this.id, @JsonKey(defaultValue: 'Unknown Artist') required this.name, @JsonKey(defaultValue: '') required this.pictureUrl, this.pictureSmall, this.pictureMedium, this.pictureBig, this.pictureXl, this.fansCount = 0, this.albumsCount = 0}): super._();
  factory _Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

@override@JsonKey(fromJson: jsonString) final  String id;
@override@JsonKey(defaultValue: 'Unknown Artist') final  String name;
@override@JsonKey(defaultValue: '') final  String pictureUrl;
@override final  String? pictureSmall;
@override final  String? pictureMedium;
@override final  String? pictureBig;
@override final  String? pictureXl;
@override@JsonKey() final  int fansCount;
@override@JsonKey() final  int albumsCount;

/// Create a copy of Artist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtistCopyWith<_Artist> get copyWith => __$ArtistCopyWithImpl<_Artist>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtistToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Artist&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.pictureUrl, pictureUrl) || other.pictureUrl == pictureUrl)&&(identical(other.pictureSmall, pictureSmall) || other.pictureSmall == pictureSmall)&&(identical(other.pictureMedium, pictureMedium) || other.pictureMedium == pictureMedium)&&(identical(other.pictureBig, pictureBig) || other.pictureBig == pictureBig)&&(identical(other.pictureXl, pictureXl) || other.pictureXl == pictureXl)&&(identical(other.fansCount, fansCount) || other.fansCount == fansCount)&&(identical(other.albumsCount, albumsCount) || other.albumsCount == albumsCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,pictureUrl,pictureSmall,pictureMedium,pictureBig,pictureXl,fansCount,albumsCount);
}

@override
String toString() {
    return 'Artist(id: $id, name: $name, pictureUrl: $pictureUrl, pictureSmall: $pictureSmall, pictureMedium: $pictureMedium, pictureBig: $pictureBig, pictureXl: $pictureXl, fansCount: $fansCount, albumsCount: $albumsCount)';
}


}

/// @nodoc
abstract mixin class _$ArtistCopyWith<$Res> implements $ArtistCopyWith<$Res> {
  factory _$ArtistCopyWith(_Artist value, $Res Function(_Artist) _then) = __$ArtistCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonString) String id,@JsonKey(defaultValue: 'Unknown Artist') String name,@JsonKey(defaultValue: '') String pictureUrl, String? pictureSmall, String? pictureMedium, String? pictureBig, String? pictureXl, int fansCount, int albumsCount
});




}
/// @nodoc
class __$ArtistCopyWithImpl<$Res>
    implements _$ArtistCopyWith<$Res> {
  __$ArtistCopyWithImpl(this._self, this._then);

  final _Artist _self;
  final $Res Function(_Artist) _then;

/// Create a copy of Artist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? pictureUrl = null,Object? pictureSmall = freezed,Object? pictureMedium = freezed,Object? pictureBig = freezed,Object? pictureXl = freezed,Object? fansCount = null,Object? albumsCount = null,}) {
  return _then(_Artist(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pictureUrl: null == pictureUrl ? _self.pictureUrl : pictureUrl // ignore: cast_nullable_to_non_nullable
as String,pictureSmall: freezed == pictureSmall ? _self.pictureSmall : pictureSmall // ignore: cast_nullable_to_non_nullable
as String?,pictureMedium: freezed == pictureMedium ? _self.pictureMedium : pictureMedium // ignore: cast_nullable_to_non_nullable
as String?,pictureBig: freezed == pictureBig ? _self.pictureBig : pictureBig // ignore: cast_nullable_to_non_nullable
as String?,pictureXl: freezed == pictureXl ? _self.pictureXl : pictureXl // ignore: cast_nullable_to_non_nullable
as String?,fansCount: null == fansCount ? _self.fansCount : fansCount // ignore: cast_nullable_to_non_nullable
as int,albumsCount: null == albumsCount ? _self.albumsCount : albumsCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
