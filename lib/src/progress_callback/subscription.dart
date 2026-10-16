import 'dart:async';
import 'dart:ui';

class ObservableBuilder<T> {
  final StreamController<T> _observable = StreamController<T>.broadcast();
  bool get notSubscribed => !_observable.hasListener;

  void next(T value) {
    if (!_observable.isClosed) _observable.add(value);
  }

  Subscription subscribe(void Function(T event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final subscription = _observable.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    return Subscription(() {
      subscription.cancel();
    });
  }

  void close() {
    _observable.close();
  }
}

class Subscription {
  final VoidCallback unsubscribe;
  const Subscription(this.unsubscribe);
}
