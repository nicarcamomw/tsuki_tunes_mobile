// Lenient readers for stored model JSON: old cache entries and documents
// written by the web app may hold a number where a string is expected, a
// missing flag or an unparsable date, and must still load.

/// Any value as text ('' when missing), e.g. ids saved as numbers.
String jsonString(Object? value) => value?.toString() ?? '';

/// Any value as text, or null when missing.
String? jsonStringOrNull(Object? value) => value?.toString();

/// Only a real `true` counts as true.
bool jsonIsTrue(Object? value) => value == true;

/// Anything but a real `false` counts as true.
bool jsonIsNotFalse(Object? value) => value != false;

/// A stored date, or now when it's missing or unparsable.
DateTime jsonDateOrNow(Object? value) =>
    (value == null ? null : DateTime.tryParse(value.toString())) ??
    DateTime.now();

/// A stored date, or the epoch when it's missing or unparsable.
DateTime jsonDateOrEpoch(Object? value) =>
    (value is String ? DateTime.tryParse(value) : null) ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// A stored date, or null when it's missing or unparsable.
DateTime? jsonDateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
