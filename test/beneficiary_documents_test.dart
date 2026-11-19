import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/beneficiary_document_model.dart';

void main() {
  group('BeneficiaryDocumentModel Tests', () {
    test('Correctly parses PDF document from API JSON', () {
      final json = {
        'id': 101,
        'beneficiary_id': 12,
        'document_type_id': 1,
        'document_name': 'Aadhaar Card',
        'document_number': 'XXXX-XXXX-1234',
        'file_name': 'aadhaar_card.pdf',
        'file_path': 'documents/aadhaar_12.pdf',
        'file_url': 'https://jankavach.indevconsultancy.in/public/storage/documents/aadhaar_12.pdf',
        'file_type': 'application/pdf',
        'file_size': 1258291, // ~1.2 MB
        'verification_status': 'Verified',
        'uploaded_at': '2026-10-15T10:30:00Z',
        'remarks': 'Biometrics verified',
      };

      final doc = BeneficiaryDocumentModel.fromJson(json);

      expect(doc.id, 101);
      expect(doc.beneficiaryId, 12);
      expect(doc.documentTypeId, 1);
      expect(doc.documentName, 'Aadhaar Card');
      expect(doc.documentNumber, 'XXXX-XXXX-1234');
      expect(doc.isPdf, isTrue);
      expect(doc.isImage, isFalse);
      expect(doc.fileFormatLabel, 'PDF');
      expect(doc.fileSize, '1.2 MB');
      expect(doc.verificationStatus, 'Verified');
      expect(doc.statusColor, const Color(0xFF21834A));
      expect(doc.formattedUploadDate, '15 Oct 2026');
      expect(doc.remarks, 'Biometrics verified');
      expect(doc.resolvedUrl, 'https://jankavach.indevconsultancy.in/public/storage/documents/aadhaar_12.pdf');
    });

    test('Correctly parses Image document from API JSON with relative path', () {
      final json = {
        'id': 102,
        'name': 'Ration Card Front',
        'document_type': {'name': 'Income & Ration'},
        'doc_number': 'RC-998877',
        'file_path': '/storage/beneficiaries/rc_front.jpg',
        'file_size': 204800, // 200 KB
        'is_verified': 0,
        'uploaded_at': '2026-11-01',
      };

      final doc = BeneficiaryDocumentModel.fromJson(json);

      expect(doc.id, 102);
      expect(doc.documentName, 'Ration Card Front');
      expect(doc.documentType, 'Income & Ration');
      expect(doc.documentNumber, 'RC-998877');
      expect(doc.isPdf, isFalse);
      expect(doc.isImage, isTrue);
      expect(doc.fileFormatLabel, 'JPEG');
      expect(doc.fileSize, '200 KB');
      expect(doc.verificationStatus, 'Pending');
      expect(doc.statusColor, Colors.orange.shade800);
      expect(doc.formattedUploadDate, '1 Nov 2026');
      // Relative path properly resolved with official host
      expect(
        doc.resolvedUrl,
        'https://jankavach.indevconsultancy.in/public/storage/beneficiaries/rc_front.jpg',
      );
    });

    test('Correctly handles generic document with unverified or rejected status', () {
      final json = {
        'id': 103,
        'title': 'Land Revenue Record',
        'file_name': 'khasra_record.docx',
        'file_type': 'docx',
        'verification_status': 'Rejected',
        'remarks': 'Document blurry, please re-upload',
      };

      final doc = BeneficiaryDocumentModel.fromJson(json);

      expect(doc.id, 103);
      expect(doc.documentName, 'Land Revenue Record');
      expect(doc.isPdf, isFalse);
      expect(doc.isImage, isFalse);
      expect(doc.fileFormatLabel, 'DOCX');
      expect(doc.verificationStatus, 'Rejected');
      expect(doc.statusColor, Colors.red.shade700);
      expect(doc.remarks, 'Document blurry, please re-upload');
    });

    test('toJson produces expected map', () {
      const doc = BeneficiaryDocumentModel(
        id: 200,
        beneficiaryId: 50,
        documentName: 'Voter ID',
        documentNumber: 'VTR-1234',
        fileName: 'voter_id.png',
        fileUrl: 'https://example.com/voter.png',
        fileType: 'image/png',
        verificationStatus: 'Verified',
      );

      final json = doc.toJson();
      expect(json['id'], 200);
      expect(json['beneficiary_id'], 50);
      expect(json['document_name'], 'Voter ID');
      expect(json['document_number'], 'VTR-1234');
      expect(json['file_name'], 'voter_id.png');
      expect(json['file_url'], 'https://example.com/voter.png');
      expect(json['verification_status'], 'Verified');
    });
  });
}
