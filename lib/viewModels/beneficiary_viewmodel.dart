
import 'package:flutter/material.dart';

import '../data/models/ beneficiary_model.dart';
import '../data/repository/beneficiary_repository.dart';


class BeneficiaryViewModel extends ChangeNotifier {
  final BeneficiaryRepository _repository = BeneficiaryRepository();

  final List<BeneficiaryModel> _beneficiaries = [];

  List<BeneficiaryModel> get beneficiaries =>
      List.unmodifiable(_beneficiaries);

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  int currentPage = 1;
  int totalPages = 1;
  int total = 0;

  Future<void> loadBeneficiaries({
    bool refresh = false,
    String? search,
  }) async {
    if (isLoading || isLoadingMore) return;

    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      _beneficiaries.clear();
    } else if (currentPage > totalPages) {
      return;
    }

    isLoading = currentPage == 1;
    isLoadingMore = currentPage > 1;
    error = null;
    notifyListeners();

    try {
      final result = await _repository.getBeneficiaries(
        page: currentPage,
        perPage: 20,
        search: search,
      );

      final fetched = result['items'] as List<BeneficiaryModel>;

      if (currentPage == 1) {
        _beneficiaries
          ..clear()
          ..addAll(fetched);
      } else {
        _beneficiaries.addAll(fetched);
      }

      currentPage = (result['page'] as int) + 1;
      totalPages = result['totalPages'] as int;
      total = result['total'] as int;
    } catch (e) {
      error = 'Unable to load beneficiaries. Please try again.';
      debugPrint('Beneficiary API error: $e');
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
