
import 'package:flutter/foundation.dart';

import '../data/models/ beneficiary_model.dart';
import '../data/repository/beneficiary_repository.dart';

class BeneficiaryViewModel extends ChangeNotifier {
  final BeneficiaryRepository _repository = BeneficiaryRepository();

  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Error state
  String? _error;

  // Beneficiary data
  List<BeneficiaryModel> _beneficiaries = [];

  // Pagination
  int _currentPage = 0;
  int _totalPages = 1;
  int _total = 0;

  // Search and filter state
  String _currentSearch = '';
  int? _villageId;
  String? _journeyStage;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;

  List<BeneficiaryModel> get beneficiaries =>
      List.unmodifiable(_beneficiaries);

  int get total => _total;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMorePages => _currentPage < _totalPages;

  /// Loads beneficiaries with pagination and search.
  Future<void> loadBeneficiaries({
    bool refresh = false,
    String? search,
    int? villageId,
    String? journeyStage,
  }) async {
    if (_isLoading || _isLoadingMore) return;

    final requestedSearch = search ?? _currentSearch;

    // Detect changes to the current filters.
    final filtersChanged =
        requestedSearch != _currentSearch ||
            (villageId != null && villageId != _villageId) ||
            (journeyStage != null &&
                journeyStage != _journeyStage);

    final shouldRefresh = refresh || filtersChanged;

    if (shouldRefresh) {
      _currentPage = 0;
    }

    _currentSearch = requestedSearch;

    if (villageId != null || shouldRefresh) {
      _villageId = villageId;
    }

    if (journeyStage != null || shouldRefresh) {
      _journeyStage = journeyStage;
    }

    final int pageToLoad =
    shouldRefresh || _beneficiaries.isEmpty
        ? 1
        : _currentPage + 1;

    if (pageToLoad > _totalPages && pageToLoad > 1) {
      return;
    }

    final bool loadingFirstPage = pageToLoad == 1;

    if (loadingFirstPage) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }

    _error = null;
    notifyListeners();

    try {
      final result = await _repository.getBeneficiaries(
        page: pageToLoad,
        perPage: 20,
        search: _currentSearch,
        villageId: _villageId,
        journeyStage: _journeyStage,
      );

      final rawItems = result['items'] as List? ?? [];

      final items = rawItems
          .whereType<BeneficiaryModel>()
          .toList();

      final responsePage =
          (result['page'] as num?)?.toInt() ?? pageToLoad;

      final responseTotalPages =
          (result['totalPages'] as num?)?.toInt() ?? 1;

      final responseTotal =
          (result['total'] as num?)?.toInt() ?? items.length;

      if (loadingFirstPage) {
        _beneficiaries = items;
      } else {
        // Avoid duplicate beneficiary IDs across pages.
        final existingIds = _beneficiaries
            .map((item) => item.id)
            .toSet();

        _beneficiaries.addAll(
          items.where(
                (item) => !existingIds.contains(item.id),
          ),
        );
      }

      _currentPage = responsePage;
      _totalPages = responseTotalPages;
      _total = responseTotal;
    } catch (e, stackTrace) {
      debugPrint('Failed to load beneficiaries: $e');
      debugPrintStack(stackTrace: stackTrace);

      _error = 'Unable to load beneficiaries. Please try again.';
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refreshes the first page using the current filters.
  Future<void> refreshBeneficiaries() async {
    await loadBeneficiaries(refresh: true);
  }

  /// Clears the beneficiary list and filter state.
  void clear() {
    _beneficiaries = [];
    _currentPage = 0;
    _totalPages = 1;
    _total = 0;
    _error = null;
    _isLoading = false;
    _isLoadingMore = false;
    _currentSearch = '';
    _villageId = null;
    _journeyStage = null;

    notifyListeners();
  }
}
