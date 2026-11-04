import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/location_model.dart';
import 'package:kavach/data/models/master_data_download_result.dart';
import 'package:kavach/data/services/connectivity_sync_service.dart';
import 'package:kavach/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Data Download Result Model Tests', () {
    test('Serializes to and deserializes from JSON correctly', () {
      final now = DateTime(2026, 10, 28, 14, 30);
      final result = MasterDataDownloadResult(
        success: true,
        message: 'Geography master data fetched successfully.',
        stateCount: 36,
        districtCount: 750,
        blockCount: 6500,
        gramPanchayatCount: 250000,
        villageCount: 650000,
        downloadedAt: now,
      );

      final json = result.toJson();
      expect(json['success'], isTrue);
      expect(json['message'], equals('Geography master data fetched successfully.'));
      expect(json['state_count'], equals(36));
      expect(json['district_count'], equals(750));
      expect(json['block_count'], equals(6500));
      expect(json['gram_panchayat_count'], equals(250000));
      expect(json['village_count'], equals(650000));
      expect(json['downloaded_at'], equals(now.toIso8601String()));

      final reconstructed = MasterDataDownloadResult.fromJson(json);
      expect(reconstructed.success, isTrue);
      expect(reconstructed.stateCount, equals(36));
      expect(reconstructed.districtCount, equals(750));
      expect(reconstructed.blockCount, equals(6500));
      expect(reconstructed.gramPanchayatCount, equals(250000));
      expect(reconstructed.villageCount, equals(650000));
      expect(reconstructed.downloadedAt.year, equals(2026));
    });

    test('Handles missing / null fields gracefully in fromJson', () {
      final result = MasterDataDownloadResult.fromJson({});
      expect(result.success, isFalse);
      expect(result.stateCount, equals(0));
      expect(result.districtCount, equals(0));
      expect(result.blockCount, equals(0));
      expect(result.gramPanchayatCount, equals(0));
      expect(result.villageCount, equals(0));
      expect(result.downloadedAt, isNotNull);
    });
  });

  group('StorageService Master Data Summary Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and retrieves master data download summary', () async {
      expect(await StorageService.getMasterDataDownloadSummary(), isNull);

      final result = MasterDataDownloadResult(
        success: true,
        message: 'Master data saved',
        stateCount: 1,
        districtCount: 75,
        blockCount: 826,
        gramPanchayatCount: 58000,
        villageCount: 106774,
        downloadedAt: DateTime.now(),
      );

      await StorageService.saveMasterDataDownloadSummary(result);

      final retrieved = await StorageService.getMasterDataDownloadSummary();
      expect(retrieved, isNotNull);
      expect(retrieved!.success, isTrue);
      expect(retrieved.stateCount, equals(1));
      expect(retrieved.districtCount, equals(75));
      expect(retrieved.blockCount, equals(826));
      expect(retrieved.gramPanchayatCount, equals(58000));
      expect(retrieved.villageCount, equals(106774));
    });
  });

  group('Geography Master Data Extraction & Grouping Logic Tests', () {
    final mockMasterPayload = {
      'states': [
        {'id': 34, 'name': 'Uttar Pradesh'},
        {'id': 10, 'name': 'Bihar'},
      ],
      'districts': [
        {'id': 605, 'state_id': 34, 'name': 'Ayodhya'},
        {'id': 606, 'state_id': 34, 'name': 'Lucknow'},
        {'id': 200, 'state_id': 10, 'name': 'Patna'},
      ],
      'blocks': [
        {'id': 201, 'district_id': 605, 'name': 'Sohawal'},
        {'id': 202, 'district_id': 605, 'name': 'Masodha'},
        {'id': 301, 'district_id': 606, 'name': 'Bakshi Ka Talab'},
      ],
      'gram_panchayats': [
        {'id': 501, 'block_id': 201, 'name': 'Deokali GP'},
        {'id': 502, 'block_id': 201, 'name': 'Rampur GP'},
        {'id': 503, 'block_id': 202, 'name': 'Bharatpur GP'},
      ],
      'villages': [
        {
          'id': 1001,
          'block_id': 201,
          'gram_panchayat_id': 501,
          'name': 'Deokali Village',
          'area_type': 'Rural',
          'pincode': '224001',
        },
        {
          'id': 1002,
          'block_id': 201,
          'gram_panchayat_id': 501,
          'name': 'Kalyanpur',
          'area_type': 'Rural',
          'pincode': '224001',
        },
        {
          'id': 1003,
          'block_id': 201,
          'gram_panchayat_id': null,
          'name': 'Direct Block Village',
          'area_type': 'Urban',
          'pincode': '224001',
        },
      ],
    };

    test('Groups districts by state_id correctly', () {
      final districts = mockMasterPayload['districts'] as List;
      final upDistricts = districts
          .where((d) => d['state_id'] == 34)
          .map((d) => LocationModel.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();

      expect(upDistricts.length, equals(2));
      expect(upDistricts.map((d) => d.name).toList(), containsAll(['Ayodhya', 'Lucknow']));

      final biharDistricts = districts
          .where((d) => d['state_id'] == 10)
          .map((d) => LocationModel.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList();

      expect(biharDistricts.length, equals(1));
      expect(biharDistricts.first.name, equals('Patna'));
    });

    test('Groups blocks by district_id correctly', () {
      final blocks = mockMasterPayload['blocks'] as List;
      final ayodhyaBlocks = blocks
          .where((b) => b['district_id'] == 605)
          .map((b) => LocationModel.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();

      expect(ayodhyaBlocks.length, equals(2));
      expect(ayodhyaBlocks.map((b) => b.name).toList(), containsAll(['Sohawal', 'Masodha']));
    });

    test('Groups gram panchayats by block_id correctly', () {
      final gps = mockMasterPayload['gram_panchayats'] as List;
      final sohawalGps = gps
          .where((gp) => gp['block_id'] == 201)
          .map((gp) => LocationModel.fromJson(Map<String, dynamic>.from(gp as Map)))
          .toList();

      expect(sohawalGps.length, equals(2));
      expect(sohawalGps.map((gp) => gp.name).toList(), containsAll(['Deokali GP', 'Rampur GP']));
    });

    test('Groups villages by gram_panchayat_id and block_id', () {
      final villages = mockMasterPayload['villages'] as List;

      // Villages by GP
      final deokaliVillages = villages
          .where((v) => v['gram_panchayat_id'] == 501)
          .map((v) => LocationModel.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();

      expect(deokaliVillages.length, equals(2));
      expect(deokaliVillages.first.pincode, equals('224001'));
      expect(deokaliVillages.first.areaType, equals('Rural'));

      // Villages by Block (including direct block villages with null GP)
      final sohawalBlockVillages = villages
          .where((v) => v['block_id'] == 201)
          .map((v) => LocationModel.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();

      expect(sohawalBlockVillages.length, equals(3));
      expect(sohawalBlockVillages.map((v) => v.name).toList(), contains('Direct Block Village'));
    });
  });

  group('Connectivity Service Check', () {
    test('ConnectivitySyncService instance exists and provides isConnected', () async {
      final service = ConnectivitySyncService.instance;
      expect(service, isNotNull);
      // In flutter_test environment without real network, isConnected should return a bool without throwing
      final connected = await service.isConnected();
      expect(connected, isA<bool>());
    });
  });
}
