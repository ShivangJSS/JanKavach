class LocationModel {
  final int id;
  final String name;
  final String? areaType;
  final String? pincode;

  const LocationModel({
    required this.id,
    required this.name,
    this.areaType,
    this.pincode,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      areaType: json['area_type']?.toString(),
      pincode: json['pincode']?.toString(),
    );
  }
}