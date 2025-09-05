// lib/extensions/stream_throttle_extension.dart
import 'dart:async';
import 'package:stream_transform/stream_transform.dart';
import 'package:bloc/bloc.dart';

/// Extension to add throttle functionality to event transformers
EventTransformer<E> throttle<E>(Duration duration) {
  return (events, mapper) {
    return events.throttle(duration).switchMap(mapper);
  };
}
