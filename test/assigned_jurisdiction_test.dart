import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assigned Jurisdiction & Location Pre-fill Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Parses nested location object (state_id, district_id, block_id)', () async {
      final userProfile = {
        'id': 18,
        'user_code': 'FU-0018',
        'name': 'Test Field Worker',
        'role': {
          'code': 'FIELD_USER',
          'name': 'Field User',
        },
        'location': {
          'state_id': 34,
          'district_id': 605,
          'block_id': 201,
        },
      };

      await StorageService.saveUserProfile(userProfile);

      final assigned = await StorageService.getUserAssignedLocation();
      expect(assigned, isNotNull);
      expect(assigned!.hasAssignedState, isTrue);
      expect(assigned.stateId, equals(34));
      expect(assigned.hasAssignedDistrict, isTrue);
      expect(assigned.districtId, equals(605));
      expect(assigned.hasAssignedBlock, isTrue);
      expect(assigned.blockId, equals(201));
    });

    test('Parses string IDs and handles null block_id gracefully', () async {
      final userProfile = {
        'id': 19,
        'location': {
          'state_id': '36',
          'district_id': '767',
          'block_id': null,
        },
      };

      await StorageService.saveUserProfile(userProfile);

      final assigned = await StorageService.getUserAssignedLocation();
      expect(assigned, isNotNull);
      expect(assigned!.stateId, equals(36));
      expect(assigned.districtId, equals(767));
      expect(assigned.hasAssignedBlock, isFalse);
      expect(assigned.blockId, isNull);
    });

    test('Preserves assigned location when user profile is updated without location field', () async {
      // Step 1: User logs in or fetches dashboard which provides location
      await StorageService.saveUserProfile({
        'id': 20,
        'username': 'field_worker_up',
        'location': {
          'state_id': 34,
          'district_id': 605,
        },
      });

      var assigned = await StorageService.getUserAssignedLocation();
      expect(assigned?.stateId, equals(34));
      expect(assigned?.districtId, equals(605));

      // Step 2: Minimal profile update from an API without location
      await StorageService.saveUserProfile({
        'id': 20,
        'username': 'field_worker_up',
        'email': 'updated@example.com',
      });

      // Location should NOT be lost
      assigned = await StorageService.getUserAssignedLocation();
      expect(assigned?.stateId, equals(34));
      expect(assigned?.districtId, equals(605));
    });

    test('Returns null when user has no assigned jurisdiction', () async {
      await StorageService.saveUserProfile({
        'id': 1,
        'username': 'admin',
        'role': {'code': 'SUPER_ADMIN'},
      });

      final assigned = await StorageService.getUserAssignedLocation();
      expect(assigned, isNull);
    });

    test('UserAssignedLocation toMap outputs correct keys', () {
      const loc = UserAssignedLocation(stateId: 34, districtId: 605, blockId: 100);
      expect(loc.toMap(), equals({
        'state_id': 34,
        'district_id': 605,
        'block_id': 100,
      }));
    });
  });
}
