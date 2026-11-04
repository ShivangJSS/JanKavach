import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../repository/scheme_repository.dart';
import 'beneficiary_sync_service.dart';

class ConnectivitySyncService {
  ConnectivitySyncService._();

  static final ConnectivitySyncService instance =
  ConnectivitySyncService._();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isSyncing = false;
  Timer? _debounceTimer;

  Future<void> start() async {
    if (_subscription != null) return;

    // Listen for network changes with debounce to update catalog data.
    // NOTE: Offline beneficiary registrations are NOT auto-synced; they sync when the user taps "Sync" on dashboard.
    _subscription = _connectivity.onConnectivityChanged.listen(
          (results) {
        if (_hasNetwork(results)) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
            unawaited(syncCatalog());
          });
        }
      },
      onError: (Object error) {
        debugPrint('Connectivity listener error: $error');
      },
    );

    // Refresh catalog when the app starts if connected.
    try {
      final results = await _connectivity.checkConnectivity();

      if (_hasNetwork(results)) {
        await syncCatalog();
      }
    } catch (error) {
      debugPrint('Initial connectivity check failed: $error');
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any(
          (result) => result != ConnectivityResult.none,
    );
  }

  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasNetwork(results);
    } catch (_) {
      return false;
    }
  }

  Future<void> syncCatalog() async {
    try {
      await SchemeRepository().syncAllSchemesOnline();
    } catch (se) {
      debugPrint('Online schemes sync error: $se');
    }
  }

  Future<int> syncNow() async {
    if (_isSyncing) return 0;

    _isSyncing = true;

    try {
      final count = await BeneficiarySyncService.instance
          .syncPendingRegistrations();

      debugPrint('Beneficiaries synced: $count');

      // Sync schemes catalogue when internet is available
      try {
        await SchemeRepository().syncAllSchemesOnline();
      } catch (se) {
        debugPrint('Online schemes sync error: $se');
      }

      return count;
    } catch (error, stackTrace) {
      debugPrint('Beneficiary sync attempt failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
