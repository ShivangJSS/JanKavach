import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/eligible_scheme_model.dart';
import '../data/services/eligible_schemes_repository.dart';

class EligibleSchemesViewModel extends ChangeNotifier {
  final EligibleSchemesRepository _repository =
  EligibleSchemesRepository();

  bool _isLoading = false;
  bool _isShowingCachedData = false;
  String? _error;
  EligibleSchemesResponse? _result;

  bool get isLoading => _isLoading;
  bool get isShowingCachedData => _isShowingCachedData;
  String? get error => _error;
  EligibleSchemesResponse? get result => _result;

  List<EligibleSchemeModel> get eligibleSchemes =>
      _result?.eligibleSchemes ?? [];

  List<EligibleSchemeModel> get potentiallyEligibleSchemes =>
      _result?.potentiallyEligibleSchemes ?? [];

  Map<String, dynamic> get summary =>
      _result?.summary ?? {};

  Future<void> checkEligibility(
    int beneficiaryId, {
    Map<String, dynamic>? beneficiaryProfile,
  }) async {
    await _fetch(
      beneficiaryId: beneficiaryId,
      request: () => _repository.checkEligibility(
        beneficiaryId: beneficiaryId,
        beneficiaryProfile: beneficiaryProfile,
      ),
    );
  }

  Future<void> loadStoredEligibility(
    int beneficiaryId, {
    Map<String, dynamic>? beneficiaryProfile,
  }) async {
    await _fetch(
      beneficiaryId: beneficiaryId,
      request: () => _repository.getStoredEligibility(
        beneficiaryId: beneficiaryId,
        beneficiaryProfile: beneficiaryProfile,
      ),
    );
  }

  Future<void> _fetch({
    required int beneficiaryId,
    required Future<EligibleSchemesResponse> Function() request,
  }) async {
    if (beneficiaryId == 0) {
      _error = 'Invalid beneficiary ID.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await request();

      if (!response.success && response.eligibleSchemes.isEmpty && response.potentiallyEligibleSchemes.isEmpty) {
        _error = response.message.isNotEmpty
            ? response.message
            : 'Unable to fetch schemes.';
      } else {
        _result = response;
        _isShowingCachedData = _repository.lastResultFromCache;
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String? serverMessage;

      if (responseData is Map) {
        serverMessage = responseData['message']?.toString() ??
            responseData['detail']?.toString();
      }

      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        _error = 'Network error. Please check your internet connection.';
      } else {
        _error = serverMessage ??
            (e.response == null
                ? 'Network error. Please check your connection.'
                : 'Unable to fetch eligible schemes '
                '(HTTP ${e.response?.statusCode ?? 'error'}).');
      }
    } catch (e, stackTrace) {
      debugPrint('Eligibility request failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
      _error = rawMsg.isNotEmpty
          ? rawMsg
          : 'Something went wrong while fetching schemes.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _result = null;
    _error = null;
    _isLoading = false;
    _isShowingCachedData = false;
    notifyListeners();
  }
}
