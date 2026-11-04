class MasterDataDownloadResult {
  final bool success;
  final String message;
  final int stateCount;
  final int districtCount;
  final int blockCount;
  final int gramPanchayatCount;
  final int villageCount;
  final DateTime downloadedAt;

  const MasterDataDownloadResult({
    required this.success,
    required this.message,
    required this.stateCount,
    required this.districtCount,
    required this.blockCount,
    required this.gramPanchayatCount,
    required this.villageCount,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'state_count': stateCount,
    'district_count': districtCount,
    'block_count': blockCount,
    'gram_panchayat_count': gramPanchayatCount,
    'village_count': villageCount,
    'downloaded_at': downloadedAt.toIso8601String(),
  };

  factory MasterDataDownloadResult.fromJson(Map<String, dynamic> json) {
    return MasterDataDownloadResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      stateCount: int.tryParse(json['state_count']?.toString() ?? '0') ?? 0,
      districtCount: int.tryParse(json['district_count']?.toString() ?? '0') ?? 0,
      blockCount: int.tryParse(json['block_count']?.toString() ?? '0') ?? 0,
      gramPanchayatCount: int.tryParse(json['gram_panchayat_count']?.toString() ?? '0') ?? 0,
      villageCount: int.tryParse(json['village_count']?.toString() ?? '0') ?? 0,
      downloadedAt: DateTime.tryParse(json['downloaded_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
