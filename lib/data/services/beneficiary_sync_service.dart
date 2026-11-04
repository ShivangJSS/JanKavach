import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../local/beneficiary_local_dao.dart';
import '../models/ beneficiary_model.dart';
import '../repository/auth_repository.dart';
import '../repository/beneficiary_repository.dart';
import 'api_service.dart';
import 'storage_service.dart';

class BeneficiarySyncService {
  BeneficiarySyncService._();

  static final BeneficiarySyncService instance = BeneficiarySyncService._();

  final BeneficiaryLocalDao _localDao = BeneficiaryLocalDao();

  bool _isSyncing = false;
  final Map<int, Future<bool>> _inFlightSyncs = {};

  bool isSyncingLocalId(int localId) => _inFlightSyncs.containsKey(localId);

  Future<int> syncPendingRegistrations() async {
    if (_isSyncing) return 0;

    _isSyncing = true;
    int syncedCount = 0;

    try {
      final pending = await _localDao.getPendingRegistrations();

      for (final record in pending) {
        final localId = record['local_id'] as int;
        final success = await syncSingleBeneficiary(localId);
        if (success) {
          syncedCount++;
        }
      }

      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> syncSingleBeneficiary(int localId) async {
    // If already in flight, await the existing future to prevent duplicate HTTP POST requests!
    if (_inFlightSyncs.containsKey(localId)) {
      return _inFlightSyncs[localId]!;
    }

    final future = _doSyncSingle(localId);
    _inFlightSyncs[localId] = future;
    try {
      return await future;
    } finally {
      _inFlightSyncs.remove(localId);
    }
  }

  Future<bool> _doSyncSingle(int localId) async {
    final record = await _localDao.getRecord(localId);
    if (record == null) return false;
    if (record['record_state'] == 'synced') return true;
    return _syncRecord(record);
  }

  Future<bool> _syncRecord(Map<String, dynamic> record) async {
    final localId = record['local_id'] as int;

    try {
      final formData = Map<String, dynamic>.from(
        record['form_data'] as Map,
      );

      final payload = Map<String, dynamic>.from(
        (formData['payload'] is Map)
            ? formData['payload'] as Map
            : formData,
      );

      // Clean empty strings to null for backend validation compatibility
      payload.forEach((key, value) {
        if (value is String && value.trim().isEmpty) {
          payload[key] = null;
        }
      });

      if (payload['relation_type'] == 'Spouse') {
        payload['relation_type'] = 'Husband';
      }

      // Auto-heal missing or mismatched assigned jurisdiction before server submission
      final assignedLoc = await StorageService.getUserAssignedLocation();
      if (assignedLoc != null) {
        if (assignedLoc.hasAssignedState &&
            (payload['state_id'] == null || payload['state_id'] != assignedLoc.stateId)) {
          payload['state_id'] = assignedLoc.stateId;
        }
        if (assignedLoc.hasAssignedDistrict &&
            (payload['district_id'] == null || payload['district_id'] != assignedLoc.districtId)) {
          payload['district_id'] = assignedLoc.districtId;
        }
        if (assignedLoc.hasAssignedBlock &&
            (payload['block_id'] == null || payload['block_id'] != assignedLoc.blockId)) {
          payload['block_id'] = assignedLoc.blockId;
        }
      }

      // Ensure we have a valid online access token prior to syncing
      final currentToken = await StorageService.getAccessToken();
      if (currentToken == null ||
          currentToken.isEmpty ||
          currentToken == 'offline_session_token') {
        await AuthRepository().loginSilentWithSavedCredentials();
      }

      Response response;
      try {
        response = await ApiService().dio.post(
          '/beneficiaries',
          data: payload,
        );
      } on DioException catch (dioErr) {
        final errData = dioErr.response?.data;
        if (dioErr.response?.statusCode == 401) {
          // Access token expired - re-authenticate silently and retry
          final reauth =
              await AuthRepository().loginSilentWithSavedCredentials();
          if (reauth) {
            response = await ApiService().dio.post(
              '/beneficiaries',
              data: payload,
            );
          } else {
            rethrow;
          }
        } else if (dioErr.response?.statusCode == 409) {
          // The beneficiary was already registered/created on the server!
          int? existingServerId;
          String? existingCode;

          if (errData is Map) {
            final dupData = errData['data'] ?? errData['duplicate_beneficiary'] ?? errData['duplicate'];
            if (dupData is Map) {
              final dupBeneficiary = dupData['beneficiary'] is Map ? dupData['beneficiary'] as Map : dupData;
              existingServerId = dupBeneficiary['id'] is int
                  ? dupBeneficiary['id'] as int
                  : int.tryParse('${dupBeneficiary['id']}');
              existingCode = dupBeneficiary['beneficiary_code']?.toString();
            }
          }

          // Locate by name and mobile in the active beneficiaries catalogue if not directly in error
          if (existingServerId == null || existingServerId <= 0) {
            try {
              final searchRes = await ApiService().dio.get(
                '/beneficiaries',
                queryParameters: {'search': payload['name'], 'per_page': 10},
              );
              final searchBody = Map<String, dynamic>.from(searchRes.data as Map);
              final searchData = Map<String, dynamic>.from(searchBody['data'] as Map? ?? {});
              final items = (searchData['items'] as List? ?? []);
              for (final it in items) {
                if (it is Map) {
                  final itName = it['name']?.toString().trim().toLowerCase();
                  final payName = payload['name']?.toString().trim().toLowerCase();
                  if (itName == payName) {
                    existingServerId = it['id'] is int ? it['id'] as int : int.tryParse('${it['id']}');
                    existingCode = it['beneficiary_code']?.toString();
                    break;
                  }
                }
              }
            } catch (_) {}
          }

          if (existingServerId != null && existingServerId > 0) {
            await _localDao.markSynced(
              localId: localId,
              serverId: existingServerId,
              beneficiaryCode: existingCode,
            );
            return true;
          }

          throw Exception(
            errData is Map && errData['message'] != null
                ? errData['message'].toString()
                : 'A beneficiary with similar details already exists on the server.',
          );
        } else {
          rethrow;
        }
      }

      final responseData = Map<String, dynamic>.from(
        response.data as Map,
      );

      if (responseData['success'] != true) {
        String errorMsg = responseData['message']?.toString() ??
            'The server rejected the registration.';
        if (responseData['errors'] is Map) {
          final errMap = responseData['errors'] as Map;
          final details = errMap.values
              .map((v) => v is List ? v.join(', ') : v.toString())
              .join('; ');
          if (details.isNotEmpty) {
            errorMsg = '$errorMsg ($details)';
          }
        }
        throw Exception(errorMsg);
      }

      final data = responseData['data'] is Map
          ? Map<String, dynamic>.from(
              responseData['data'] as Map,
            )
          : <String, dynamic>{};

      final beneficiaryData = data['beneficiary'] is Map
          ? Map<String, dynamic>.from(data['beneficiary'] as Map)
          : data;

      int? serverId = beneficiaryData['id'] is int
          ? beneficiaryData['id'] as int
          : (int.tryParse('${beneficiaryData['id']}') ??
              int.tryParse('${beneficiaryData['beneficiary_id']}') ??
              int.tryParse('${data['beneficiary_id']}') ??
              int.tryParse('${data['id']}') ??
              int.tryParse('${responseData['id']}'));

      final beneficiaryCode = beneficiaryData['beneficiary_code']?.toString() ??
          beneficiaryData['code']?.toString() ??
          data['beneficiary_code']?.toString() ??
          data['code']?.toString() ??
          responseData['code']?.toString();

      if (serverId == null || serverId <= 0) {
        throw Exception(
          'Server response did not contain a valid beneficiary ID.',
        );
      }

      await _localDao.markSynced(
        localId: localId,
        serverId: serverId,
        beneficiaryCode: beneficiaryCode,
      );

      // Cache the synced beneficiary locally in beneficiary_cache
      try {
        await BeneficiaryRepository().cacheSingleBeneficiary(
          BeneficiaryModel(
            id: serverId,
            beneficiaryCode: beneficiaryCode ?? '',
            name: payload['name']?.toString() ?? '',
            gender: payload['gender']?.toString(),
            dob: payload['dob']?.toString(),
            age: payload['age'] is num
                ? (payload['age'] as num).toInt()
                : int.tryParse('${payload['age']}'),
            mobile: payload['mobile']?.toString(),
            stateId: payload['state_id'] as int?,
            districtId: payload['district_id'] as int?,
            blockId: payload['block_id'] as int?,
            gramPanchayatId: payload['gram_panchayat_id'] as int?,
            villageId: payload['village_id'] as int?,
            villageName: payload['village_name']?.toString(),
            recordStatus: 'Active',
            assessmentStatus: 'Registered',
            registrationDate: payload['registration_date']?.toString(),
            journeyStage: 1,
            applicationCount: 0,
          ),
        );
      } catch (_) {}

      return true;
    } catch (e) {
      String errorMessage;

      if (e is DioException) {
        final status = e.response?.statusCode;
        final resData = e.response?.data;
        String? serverMsg;
        if (resData is Map) {
          serverMsg = resData['message']?.toString();
          if (resData['errors'] is Map) {
            final errMap = resData['errors'] as Map;
            final details = errMap.values
                .map((v) => v is List ? v.join(', ') : v.toString())
                .join('; ');
            if (details.isNotEmpty) {
              serverMsg = (serverMsg != null && serverMsg.isNotEmpty)
                  ? '$serverMsg ($details)'
                  : details;
            }
          }
        }

        if (status == 401) {
          errorMessage = 'Authentication failed. Please log in again.';
        } else if (serverMsg != null && serverMsg.isNotEmpty) {
          errorMessage = serverMsg;
        } else if (status != null) {
          errorMessage = 'Server returned HTTP $status.';
        } else {
          errorMessage = 'Network unavailable.';
        }
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      }

      debugPrint('Beneficiary sync error (localId $localId): $errorMessage');

      await _localDao.markSyncFailed(
        localId: localId,
        error: errorMessage,
      );

      return false;
    }
  }
}
