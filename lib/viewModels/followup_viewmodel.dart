import 'package:flutter/foundation.dart';
import '../data/models/followup_model.dart';
import '../data/repository/followup_repository.dart';

class FollowupViewModel extends ChangeNotifier {
  final FollowupRepository _repository;

  FollowupViewModel({FollowupRepository? repository})
      : _repository = repository ?? FollowupRepository();

  // Dashboard state
  FollowupDashboardData? _dashboardData;
  bool _isLoadingDashboard = false;
  String? _dashboardError;

  // Register list state
  List<FollowupRegisterItem> _registerItems = [];
  bool _isLoadingRegister = false;
  bool _isLoadingMore = false;
  String? _registerError;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  String _statusFilter = 'all';
  String _dueFilter = 'all';
  String _searchQuery = '';

  // Getters
  FollowupDashboardData? get dashboardData => _dashboardData;
  bool get isLoadingDashboard => _isLoadingDashboard;
  String? get dashboardError => _dashboardError;

  List<FollowupRegisterItem> get registerItems => List.unmodifiable(_registerItems);
  bool get isLoadingRegister => _isLoadingRegister;
  bool get isLoadingMore => _isLoadingMore;
  String? get registerError => _registerError;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get hasMorePages => _currentPage < _totalPages;

  String get statusFilter => _statusFilter;
  String get dueFilter => _dueFilter;
  String get searchQuery => _searchQuery;

  /// Loads both the dashboard summary metrics and the register list.
  Future<void> initialize({String? initialDueFilter}) async {
    if (initialDueFilter != null) {
      _dueFilter = initialDueFilter;
    }
    await Future.wait([
      loadDashboardMetrics(),
      loadRegister(refresh: true),
    ]);
  }

  Future<void> loadDashboardMetrics() async {
    _isLoadingDashboard = true;
    _dashboardError = null;
    notifyListeners();

    try {
      _dashboardData = await _repository.getDashboardMetrics();
    } catch (e) {
      _dashboardError = e.toString();
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  /// Evaluates whether a given next follow-up date and status match the due filter category.
  static bool matchesDueFilter(String? nextFollowupDateStr, String dueFilter, {String? status}) {
    if (dueFilter == 'all') return true;
    if (nextFollowupDateStr == null || nextFollowupDateStr.trim().isEmpty) return false;
    
    // Items with 'Complete' status are not due
    if (status != null && status.toLowerCase() == 'complete') return false;

    DateTime? date;
    try {
      final cleanStr = nextFollowupDateStr.trim().split(' ').first;
      date = DateTime.parse(cleanStr);
    } catch (_) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (dueFilter == 'today') {
      return target.isAtSameMomentAs(today);
    } else if (dueFilter == 'overdue') {
      return target.isBefore(today);
    } else if (dueFilter == 'upcoming') {
      final weekLater = today.add(const Duration(days: 7));
      return target.isAfter(today) && (target.isBefore(weekLater) || target.isAtSameMomentAs(weekLater));
    }
    return true;
  }

  Future<void> loadRegister({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _isLoadingRegister = true;
      _registerError = null;
      notifyListeners();
    } else {
      if (_isLoadingMore || !hasMorePages) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final response = await _repository.getRegister(
        page: _currentPage,
        perPage: 20,
        status: _statusFilter,
        dueFilter: _dueFilter,
        search: _searchQuery,
      );

      List<FollowupRegisterItem> items = response.items;
      if (_dueFilter != 'all') {
        items = items.where((it) => matchesDueFilter(it.nextFollowupDate, _dueFilter, status: it.status)).toList();
      }

      if (refresh) {
        _registerItems = items;
      } else {
        _registerItems.addAll(items);
      }

      _currentPage = response.currentPage;
      _totalPages = response.totalPages;
      if (_dueFilter != 'all') {
        _totalItems = _registerItems.length;
      } else {
        _totalItems = response.totalItems;
      }
    } catch (e) {
      _registerError = e.toString();
    } finally {
      _isLoadingRegister = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (!hasMorePages || _isLoadingMore || _isLoadingRegister) return;
    _currentPage++;
    await loadRegister(refresh: false);
  }

  void setStatusFilter(String status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    if ((_statusFilter == 'Complete' || _statusFilter == 'Applied') && _dueFilter != 'all') {
      _dueFilter = 'all';
    }
    loadRegister(refresh: true);
  }

  void setDueFilter(String dueFilter) {
    if (_dueFilter == dueFilter) return;
    _dueFilter = dueFilter;
    if (_dueFilter != 'all' && (_statusFilter == 'Complete' || _statusFilter == 'Applied')) {
      _statusFilter = 'all';
    }
    loadRegister(refresh: true);
  }

  void setSearch(String search) {
    _searchQuery = search.trim();
    loadRegister(refresh: true);
  }

  Future<bool> recordFollowup(RecordFollowupPayload payload) async {
    try {
      await _repository.recordFollowup(payload);
      // Refresh dashboard and register to reflect state transitions
      await Future.wait([
        loadDashboardMetrics(),
        loadRegister(refresh: true),
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }
}
