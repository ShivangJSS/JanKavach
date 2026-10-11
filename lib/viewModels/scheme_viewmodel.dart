
import 'package:flutter/material.dart';
import '../data/models/scheme_model.dart';
import '../data/repository/scheme_repository.dart';

class SchemeViewModel extends ChangeNotifier {
  final SchemeRepository _repository = SchemeRepository();

  final List<SchemeModel> _schemes = [];

  List<SchemeModel> get schemes => List.unmodifiable(_schemes);
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  int currentPage = 1;
  int totalPages = 1;
  int total = 0;

  Future<void> loadSchemes({bool refresh = false, String? search}) async {
    if (isLoading || isLoadingMore) return;

    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      _schemes.clear();
    } else if (currentPage > totalPages) {
      return;
    }

    isLoading = currentPage == 1;
    isLoadingMore = currentPage > 1;
    error = null;
    notifyListeners();

    try {
      final result = await _repository.getSchemes(
        page: currentPage,
        perPage: 20,
        search: search,
      );

      final fetched = result['items'] as List<SchemeModel>;

      if (currentPage == 1) {
        _schemes
          ..clear()
          ..addAll(fetched);
      } else {
        _schemes.addAll(fetched);
      }

      currentPage = (result['page'] as int) + 1;
      totalPages = result['totalPages'] as int;
      total = result['total'] as int;
    } catch (e) {
      error = 'Unable to load schemes. Please try again.';
      debugPrint('Schemes API error: $e');
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
