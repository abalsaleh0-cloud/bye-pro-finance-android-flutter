import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeAddRequestProvider =
    NotifierProvider<HomeAddRequestNotifier, int>(HomeAddRequestNotifier.new);

class HomeAddRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
