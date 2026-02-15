import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for tracking the currently selected tab in the home screen
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0; // Default to Timeline tab
  
  void setTab(int index) {
    state = index;
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(() {
  return SelectedTabNotifier();
});
