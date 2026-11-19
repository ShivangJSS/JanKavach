import 'package:flutter/material.dart';

class BeneficiaryDocumentModel {
  final int id;
  final int? beneficiaryId;
  final int? documentTypeId;
  final String documentName;
  final String? documentType;
  final String? documentNumber;
  final String? fileName;
  final String? filePath;
  final String? fileUrl;
  final String? fileType;
  final String? fileSize;
  final String verificationStatus;
  final String? uploadedAt;
  final String? remarks;

  const BeneficiaryDocumentModel({
    required this.id,
    this.beneficiaryId,
    this.documentTypeId,
    required this.documentName,
    this.documentType,
    this.documentNumber,
    this.fileName,
    this.filePath,
    this.fileUrl,
    this.fileType,
    this.fileSize,
    this.verificationStatus = 'Pending',
    this.uploadedAt,
    this.remarks,
  });

  factory BeneficiaryDocumentModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] is num) {
      parsedId = (json['id'] as num).toInt();
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    int? parsedBeneficiaryId;
    if (json['beneficiary_id'] is num) {
      parsedBeneficiaryId = (json['beneficiary_id'] as num).toInt();
    } else if (json['beneficiary_id'] != null) {
      parsedBeneficiaryId = int.tryParse(json['beneficiary_id'].toString());
    }

    int? parsedDocTypeId;
    if (json['document_type_id'] is num) {
      parsedDocTypeId = (json['document_type_id'] as num).toInt();
    } else if (json['document_type_id'] != null) {
      parsedDocTypeId = int.tryParse(json['document_type_id'].toString());
    }

    // Extract document name
    String? name = json['document_name']?.toString() ??
        json['name']?.toString() ??
        json['doc_name']?.toString() ??
        json['title']?.toString();

    if (name == null || name.trim().isEmpty) {
      if (json['document_type'] is Map) {
        name = json['document_type']['name']?.toString() ??
            json['document_type']['title']?.toString();
      } else if (json['document_type'] is String &&
          json['document_type'].toString().trim().isNotEmpty) {
        name = json['document_type'].toString();
      }
    }

    if (name == null || name.trim().isEmpty) {
      name = json['file_name']?.toString() ?? 'Document';
    }

    // Extract document type / category
    String? type;
    if (json['document_type'] is Map) {
      type = json['document_type']['name']?.toString() ??
          json['document_type']['category']?.toString();
    } else if (json['document_type'] is String) {
      type = json['document_type'].toString();
    }
    type ??= json['category']?.toString() ?? json['type']?.toString();

    // Extract file name & url
    final rawUrl = json['file_url']?.toString() ??
        json['url']?.toString() ??
        json['download_url']?.toString() ??
        json['document_url']?.toString() ??
        json['view_url']?.toString();

    final rawPath = json['file_path']?.toString() ?? json['path']?.toString();

    String? parsedFileName =
        json['file_name']?.toString() ?? json['filename']?.toString();
    if (parsedFileName == null || parsedFileName.isEmpty) {
      if (rawPath != null && rawPath.isNotEmpty) {
        parsedFileName = rawPath.split('/').last.split('\\').last;
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        final cleanUrl = rawUrl.split('?').first;
        parsedFileName = cleanUrl.split('/').last;
      }
    }

    // Format file size
    String? formattedSize;
    final rawSize = json['file_size'] ?? json['size'];
    if (rawSize != null) {
      if (rawSize is num) {
        final bytes = rawSize.toDouble();
        if (bytes >= 1048576) {
          formattedSize = '${(bytes / 1048576).toStringAsFixed(1)} MB';
        } else if (bytes >= 1024) {
          formattedSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
        } else {
          formattedSize = '${bytes.toInt()} B';
        }
      } else {
        formattedSize = rawSize.toString();
      }
    }

    // Verification status
    String status = json['verification_status']?.toString() ??
        json['status']?.toString() ??
        json['verify_status']?.toString() ??
        '';

    if (status.isEmpty) {
      if (json['is_verified'] == true ||
          json['is_verified'] == 1 ||
          json['is_verified'] == '1') {
        status = 'Verified';
      } else {
        status = 'Pending';
      }
    }

    return BeneficiaryDocumentModel(
      id: parsedId,
      beneficiaryId: parsedBeneficiaryId,
      documentTypeId: parsedDocTypeId,
      documentName: name.trim(),
      documentType: type?.trim(),
      documentNumber: json['document_number']?.toString() ??
          json['doc_number']?.toString() ??
          json['number']?.toString() ??
          json['certificate_no']?.toString(),
      fileName: parsedFileName?.trim(),
      filePath: rawPath?.trim(),
      fileUrl: (rawUrl ?? rawPath)?.trim(),
      fileType: json['file_type']?.toString() ??
          json['mime_type']?.toString() ??
          json['extension']?.toString() ??
          json['format']?.toString(),
      fileSize: formattedSize,
      verificationStatus: status.trim(),
      uploadedAt: json['uploaded_at']?.toString() ??
          json['created_at']?.toString() ??
          json['upload_date']?.toString() ??
          json['date']?.toString(),
      remarks: json['remarks']?.toString() ??
          json['notes']?.toString() ??
          json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (documentTypeId != null) 'document_type_id': documentTypeId,
      'document_name': documentName,
      if (documentType != null) 'document_type': documentType,
      if (documentNumber != null) 'document_number': documentNumber,
      if (fileName != null) 'file_name': fileName,
      if (filePath != null) 'file_path': filePath,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileType != null) 'file_type': fileType,
      if (fileSize != null) 'file_size': fileSize,
      'verification_status': verificationStatus,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (remarks != null) 'remarks': remarks,
    };
  }

  /// Determines whether the document is a PDF.
  bool get isPdf {
    final lowerType = (fileType ?? '').toLowerCase();
    if (lowerType.contains('pdf')) return true;
    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.pdf')) return true;
    final lowerUrl = (fileUrl ?? '').toLowerCase();
    return lowerUrl.contains('.pdf');
  }

  /// Determines whether the document is an image.
  bool get isImage {
    final lowerType = (fileType ?? '').toLowerCase();
    if (lowerType.contains('image') ||
        lowerType.contains('jpg') ||
        lowerType.contains('jpeg') ||
        lowerType.contains('png') ||
        lowerType.contains('webp')) {
      return true;
    }
    final lowerName = (fileName ?? '').toLowerCase();
    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.bmp')) {
      return true;
    }
    final lowerUrl = (fileUrl ?? '').toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.webp');
  }

  /// Clean display label for file extension/type.
  String get fileFormatLabel {
    if (isPdf) return 'PDF';
    if (isImage) {
      if ((fileName ?? '').toLowerCase().endsWith('.png')) return 'PNG';
      return 'JPEG';
    }
    if (fileType != null && fileType!.isNotEmpty) {
      return fileType!.split('/').last.toUpperCase();
    }
    return 'FILE';
  }

  /// Resolves relative URLs against the official backend base URL.
  String get resolvedUrl {
    final raw = fileUrl ?? filePath ?? '';
    if (raw.trim().isEmpty) return '';

    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    const String host = "https://jankavach.indevconsultancy.in";

    if (trimmed.startsWith('/public/')) {
      return '$host$trimmed';
    }
    if (trimmed.startsWith('public/')) {
      return '$host/$trimmed';
    }
    if (trimmed.startsWith('/storage/') || trimmed.startsWith('storage/')) {
      final clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return '$host/public$clean';
    }
    if (trimmed.startsWith('/')) {
      return '$host$trimmed';
    }
    return '$host/$trimmed';
  }

  /// Formatted date e.g. "15 Oct 2026"
  String? get formattedUploadDate {
    if (uploadedAt == null || uploadedAt!.isEmpty) return null;
    final parsed = DateTime.tryParse(uploadedAt!);
    if (parsed == null) return uploadedAt;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  /// Color for verification status chip
  Color get statusColor {
    final s = verificationStatus.toLowerCase().trim();
    if (s == 'verified' || s == 'approved' || s == 'valid') {
      return const Color(0xFF21834A);
    }
    if (s == 'pending' ||
        s == 'under review' ||
        s == 'in review' ||
        s == 'submitted') {
      return Colors.orange.shade800;
    }
    if (s == 'rejected' || s == 'declined' || s == 'invalid') {
      return Colors.red.shade700;
    }
    return Colors.blueGrey;
  }
}
