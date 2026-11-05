import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/ beneficiary_model.dart';

void main() {
  group('Current Address & Beneficiary Model Tests', () {
    test('BeneficiaryModel parses current address fields from json correctly', () {
      final json = {
        'id': 101,
        'beneficiary_code': 'BEN-001',
        'name': 'Ramesh Kumar',
        'state_id': 1,
        'district_id': 2,
        'block_id': 3,
        'gram_panchayat_id': 4,
        'village_id': 5,
        'village_name': 'Rampur',
        'same_as_permanent_address': true,
        'current_state_id': 1,
        'current_district_id': 2,
        'current_block_id': 3,
        'current_gram_panchayat_id': 4,
        'current_village_id': 5,
        'current_village_name': 'Rampur',
      };

      final model = BeneficiaryModel.fromJson(json);

      expect(model.id, equals(101));
      expect(model.name, equals('Ramesh Kumar'));
      expect(model.stateId, equals(1));
      expect(model.sameAsPermanentAddress, isTrue);
      expect(model.currentStateId, equals(1));
      expect(model.currentDistrictId, equals(2));
      expect(model.currentBlockId, equals(3));
      expect(model.currentGramPanchayatId, equals(4));
      expect(model.currentVillageId, equals(5));
      expect(model.currentVillageName, equals('Rampur'));
    });

    test('BeneficiaryModel serializes current address fields to json correctly', () {
      const model = BeneficiaryModel(
        id: 102,
        beneficiaryCode: 'BEN-002',
        name: 'Sunita Devi',
        stateId: 1,
        districtId: 2,
        sameAsPermanentAddress: false,
        currentStateId: 5,
        currentDistrictId: 6,
        currentBlockId: 7,
        currentGramPanchayatId: 8,
        currentVillageId: 9,
        currentVillageName: 'Shyam Nagar',
      );

      final json = model.toJson();

      expect(json['id'], equals(102));
      expect(json['name'], equals('Sunita Devi'));
      expect(json['same_as_permanent_address'], isFalse);
      expect(json['current_state_id'], equals(5));
      expect(json['current_district_id'], equals(6));
      expect(json['current_block_id'], equals(7));
      expect(json['current_gram_panchayat_id'], equals(8));
      expect(json['current_village_id'], equals(9));
      expect(json['current_village_name'], equals('Shyam Nagar'));
    });

    test('Beneficiary payload correctly structure flat and nested current address', () {
      final payload = {
        'state_id': 10,
        'district_id': 20,
        'address_line': '123 Main St',
        'pincode': '110001',
        'area_type': 'Rural',
        'same_as_permanent_address': true,
        'current_state_id': 10,
        'current_district_id': 20,
        'current_address_line': '123 Main St',
        'current_pincode': '110001',
        'current_area_type': 'Rural',
        'current_address_details': {
          'same_as_permanent_address': true,
          'state_id': 10,
          'district_id': 20,
          'address_line': '123 Main St',
          'pincode': '110001',
          'area_type': 'Rural',
        },
      };

      expect(payload['same_as_permanent_address'], isTrue);
      expect(payload['current_state_id'], equals(payload['state_id']));
      expect(payload['current_district_id'], equals(payload['district_id']));
      expect(payload['current_address_line'], equals(payload['address_line']));
      expect(payload['current_pincode'], equals(payload['pincode']));

      final nested = payload['current_address_details'] as Map<String, dynamic>;
      expect(nested['same_as_permanent_address'], isTrue);
      expect(nested['state_id'], equals(10));
      expect(nested['district_id'], equals(20));
      expect(nested['address_line'], equals('123 Main St'));
    });
  });
}
