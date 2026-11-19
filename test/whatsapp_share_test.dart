import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/eligible_scheme_model.dart';
import 'package:kavach/data/services/whatsapp_share_service.dart';

void main() {
  group('WhatsAppShareService Tests', () {
    const testScheme = EligibleSchemeModel(
      schemeCode: 'JK-SCH-0025',
      schemeName: 'Pradhan Mantri Awaas Yojana - Gramin (PMAY-G)',
      shortName: 'PMAY-G',
      schemeLevel: 'National',
      eligibilityStatus: 'Eligible',
      matchPercent: 100.0,
      description: 'Housing assistance for rural poor',
      theme: {'name': 'Rural Development'},
      benefit: {
        'amount_text': '1.2 Lakh in plain areas, 1.3 Lakh in hilly areas',
        'description': 'Financial grant for building pucca house',
      },
      application: {
        'mode': 'Offline',
        'process': 'Submit application at Gram Panchayat or Block Office with property documents.',
        'portal_url': 'https://pmayg.nic.in',
        'helpline_number': '1800-11-6446',
      },
      missingDocuments: ['Aadhaar Card', 'Bank Passbook', 'MGNREGA Job Card'],
    );

    test('formatSchemeMessage produces complete and structured WhatsApp text', () {
      final message = WhatsAppShareService.formatSchemeMessage(
        scheme: testScheme,
        beneficiaryName: 'Ramesh Kumar',
        beneficiaryCode: 'JK-BEN-0042',
      );

      // Verify header and beneficiary
      expect(message, contains('Jan Kavach - Welfare Scheme Information'));
      expect(message, contains('Ramesh Kumar'));
      expect(message, contains('JK-BEN-0042'));

      // Verify scheme essentials
      expect(message, contains('Pradhan Mantri Awaas Yojana - Gramin (PMAY-G)'));
      expect(message, contains('JK-SCH-0025'));
      expect(message, contains('Rural Development'));
      expect(message, contains('100% Match'));

      // Verify benefits and application details
      expect(message, contains('Financial grant for building pucca house'));
      expect(message, contains('Offline'));
      expect(message, contains('Gram Panchayat or Block Office'));

      // Verify documents checklist
      expect(message, contains('Aadhaar Card'));
      expect(message, contains('Bank Passbook'));
      expect(message, contains('MGNREGA Job Card'));

      // Verify links and helpline
      expect(message, contains('https://pmayg.nic.in'));
      expect(message, contains('1800-11-6446'));
    });

    test('formatSchemeMessage works without beneficiary name or code', () {
      final message = WhatsAppShareService.formatSchemeMessage(
        scheme: testScheme,
      );

      expect(message, contains('Pradhan Mantri Awaas Yojana - Gramin (PMAY-G)'));
      expect(message, contains('JK-SCH-0025'));
      expect(message, contains('Jan Kavach'));
    });

    test('formatSchemeMessage produces complete Hindi WhatsApp text when languageCode is hi', () {
      final message = WhatsAppShareService.formatSchemeMessage(
        scheme: testScheme,
        languageCode: 'hi',
        beneficiaryName: 'रमेश कुमार',
        beneficiaryCode: 'JK-BEN-0042',
      );

      expect(message, contains('जन कवच - कल्याणकारी योजना जानकारी'));
      expect(message, contains('रमेश कुमार'));
      expect(message, contains('योजना का नाम:'));
      expect(message, contains('योजना के लाभ:'));
      expect(message, contains('आवेदन का माध्यम:'));
      expect(message, contains('आवश्यक दस्तावेज़ सूची:'));
      expect(message, contains('आधार कार्ड'));
      expect(message, contains('बैंक पासबुक'));
      expect(message, contains('हेल्पलाइन नंबर:'));
    });

    test('formatSchemeMessage produces complete Assamese WhatsApp text when languageCode is as', () {
      final message = WhatsAppShareService.formatSchemeMessage(
        scheme: testScheme,
        languageCode: 'as',
        beneficiaryName: 'ৰমেশ কুমাৰ',
        beneficiaryCode: 'JK-BEN-0042',
      );

      expect(message, contains('জন কৱচ - কল্যাণমূলক আঁচনিৰ তথ্য'));
      expect(message, contains('ৰমেশ কুমাৰ'));
      expect(message, contains('আঁচনিৰ নাম:'));
      expect(message, contains('আঁচনিৰ সুবিধাসমূহ:'));
      expect(message, contains('আবেদনৰ মাধ্যম:'));
      expect(message, contains('প্ৰয়োজনীয় নথি-পত্ৰসমূহৰ তালিকা:'));
      expect(message, contains('আধাৰ কাৰ্ড'));
      expect(message, contains('বেংক পাছবুক'));
      expect(message, contains('হেল্পলাইন নম্বৰ:'));
    });

    test('cleanPhoneNumber sanitizes 10-digit Indian numbers with 91 prefix', () {
      expect(WhatsAppShareService.cleanPhoneNumber('9876543210'), equals('919876543210'));
      expect(WhatsAppShareService.cleanPhoneNumber('+91 98765 43210'), equals('919876543210'));
      expect(WhatsAppShareService.cleanPhoneNumber('919876543210'), equals('919876543210'));
      expect(WhatsAppShareService.cleanPhoneNumber('09876543210'), equals('09876543210'));
    });

    test('cleanPhoneNumber returns null for invalid or null numbers', () {
      expect(WhatsAppShareService.cleanPhoneNumber(null), isNull);
      expect(WhatsAppShareService.cleanPhoneNumber(''), isNull);
      expect(WhatsAppShareService.cleanPhoneNumber('123'), isNull);
    });
  });
}
