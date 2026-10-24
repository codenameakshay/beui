final List<Map<String, Object?>> initialEditTrace = <Map<String, Object?>>[];
final Stopwatch initialEditClock = Stopwatch()..start();
void traceInitialEdit(String event, [Map<String, Object?> detail = const {}]) {
  if (initialEditTrace.length < 200) {
    initialEditTrace.add(<String, Object?>{'us': initialEditClock.elapsedMicroseconds, 'event': event, ...detail});
  }
}

