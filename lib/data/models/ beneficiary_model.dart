
class BeneficiaryModel {
  final int id;
  final String beneficiaryCode;
  final String name;
  final String? gender;
  final String? dob;
  final int? age;
  final String? mobile;
  final int? stateId;
  final int? districtId;
  final int? blockId;
  final int? gramPanchayatId;
  final int? villageId;
  final String? villageName;
  final bool? sameAsPermanentAddress;
  final int? currentStateId;
  final int? currentDistrictId;
  final int? currentBlockId;
  final int? currentGramPanchayatId;
  final int? currentVillageId;
  final String? currentVillageName;
  final String? recordStatus;
  final String? assessmentStatus;
  final String? registrationDate;
  final int journeyStage;
  final int applicationCount;

  const BeneficiaryModel({
    required this.id,
    required this.beneficiaryCode,
    required this.name,
    this.gender,
    this.dob,
    this.age,
    this.mobile,
    this.stateId,
    this.districtId,
    this.blockId,
    this.gramPanchayatId,
    this.villageId,
    this.villageName,
    this.sameAsPermanentAddress,
    this.currentStateId,
    this.currentDistrictId,
    this.currentBlockId,
    this.currentGramPanchayatId,
    this.currentVillageId,
    this.currentVillageName,
    this.recordStatus,
    this.assessmentStatus,
    this.registrationDate,
    this.journeyStage = 0,
    this.applicationCount = 0,
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      final result = value.toString().trim();
      return result.isEmpty ? null : result;
    }

    return BeneficiaryModel(
      id: parseInt(json['id']) ?? 0,
      beneficiaryCode:
      parseString(json['beneficiary_code']) ?? '',
      name: parseString(json['name']) ?? 'Unnamed beneficiary',
      gender: parseString(json['gender']),
      dob: parseString(json['dob']),
      age: parseInt(json['age']),
      mobile: parseString(json['mobile']),
      stateId: parseInt(json['state_id']),
      districtId: parseInt(json['district_id']),
      blockId: parseInt(json['block_id']),
      gramPanchayatId: parseInt(json['gram_panchayat_id']),
      villageId: parseInt(json['village_id']),
      villageName: parseString(json['village_name']),
      sameAsPermanentAddress: json['same_as_permanent_address'] == true,
      currentStateId: parseInt(json['current_state_id']),
      currentDistrictId: parseInt(json['current_district_id']),
      currentBlockId: parseInt(json['current_block_id']),
      currentGramPanchayatId: parseInt(json['current_gram_panchayat_id']),
      currentVillageId: parseInt(json['current_village_id']),
      currentVillageName: parseString(json['current_village_name']),
      recordStatus: parseString(json['record_status']),
      assessmentStatus: parseString(json['assessment_status']),
      registrationDate: parseString(json['registration_date']),
      journeyStage: parseInt(json['journey_stage']) ?? 0,
      applicationCount: parseInt(json['application_count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'beneficiary_code': beneficiaryCode,
      'name': name,
      'gender': gender,
      'dob': dob,
      'age': age,
      'mobile': mobile,
      'state_id': stateId,
      'district_id': districtId,
      'block_id': blockId,
      'gram_panchayat_id': gramPanchayatId,
      'village_id': villageId,
      'village_name': villageName,
      'same_as_permanent_address': sameAsPermanentAddress,
      'current_state_id': currentStateId,
      'current_district_id': currentDistrictId,
      'current_block_id': currentBlockId,
      'current_gram_panchayat_id': currentGramPanchayatId,
      'current_village_id': currentVillageId,
      'current_village_name': currentVillageName,
      'record_status': recordStatus,
      'assessment_status': assessmentStatus,
      'registration_date': registrationDate,
      'journey_stage': journeyStage,
      'application_count': applicationCount,
    };
  }
}
