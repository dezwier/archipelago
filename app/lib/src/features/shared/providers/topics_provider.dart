import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/data/topic_service.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';

/// Provider that manages topics list and loading state.
/// Automatically reloads topics when user logs in/out.
class TopicsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  List<Topic> _topics = [];
  bool _isLoading = false;
  String? _errorMessage;

  TopicsProvider(this._authProvider) {
    // Listen to auth changes to reload topics
    _authProvider.addListener(_onAuthChanged);
    // Load topics initially
    _loadTopics();
  }

  List<Topic> get topics => _topics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _onAuthChanged() {
    // Reload topics when user logs in/out
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _authProvider.currentUser?.id;
      final topics = await TopicService.getTopics(userId: userId);
      _topics = topics;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load topics: ${e.toString()}';
      _topics = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refresh topics (e.g., after creating a new topic)
  Future<void> refresh() async {
    await _loadTopics();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}

