import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/beneficiary_document_model.dart';
import '../../data/services/storage_service.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final BeneficiaryDocumentModel document;
  final String? beneficiaryName;

  const DocumentPreviewScreen({
    super.key,
    required this.document,
    this.beneficiaryName,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  static const Color _green = Color(0xFF21834A);
  static const Color _background = Color(0xFFF5F8F5);

  Map<String, String> _authHeaders = {};
  bool _isLoadingToken = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final token = await StorageService.getAccessToken();
    if (!mounted) return;

    setState(() {
      if (token != null &&
          token.isNotEmpty &&
          token != 'offline_session_token') {
        _authHeaders = {'Authorization': 'Bearer $token'};
      }
      _isLoadingToken = false;
    });
  }

  Future<void> _openOrDownloadDocument() async {
    final url = widget.document.resolvedUrl;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document URL is not available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final uri = Uri.parse(url);

      // 1. If on Web, open directly in external browser tab
      if (kIsWeb) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) throw Exception('Could not launch document URL');
        return;
      }

      // 2. On Mobile/Desktop: Download securely with Bearer token, then open with native viewer
      try {
        final tempDir = Directory.systemTemp;
        String fileName = widget.document.fileName ??
            (widget.document.isPdf
                ? 'document_${widget.document.id}.pdf'
                : 'document_${widget.document.id}.bin');

        // Sanitize file name
        fileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final filePath = '${tempDir.path}/$fileName';

        await Dio().download(
          url,
          filePath,
          options: Options(
            headers: _authHeaders,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        final fileUri = Uri.file(filePath);
        final launched = await launchUrl(
          fileUri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          // Fallback to direct URI launch
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (dioError) {
        debugPrint('Secure download fallback to direct launch: $dioError');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception('Unable to open document: $dioError');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open document: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16231C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final resolvedUrl = doc.resolvedUrl;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(
          doc.documentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (resolvedUrl.isNotEmpty)
            IconButton(
              tooltip: 'Open in external viewer',
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_new_rounded),
              onPressed: _isDownloading ? null : _openOrDownloadDocument,
            ),
        ],
      ),
      body: _isLoadingToken
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Beneficiary tag
                  if (widget.beneficiaryName != null &&
                      widget.beneficiaryName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            widget.beneficiaryName!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main Preview Area
                  if (doc.isImage && resolvedUrl.isNotEmpty)
                    _buildImagePreview(resolvedUrl)
                  else if (doc.isPdf)
                    _buildPdfPreviewCard(doc)
                  else
                    _buildGenericFileCard(doc),

                  const SizedBox(height: 20),

                  // Document Information Card matching BeneficiaryDetailScreen style
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: _green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Document Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16231C),
                              ),
                            ),
                            const Spacer(),
                            _statusChip(
                              doc.verificationStatus,
                              doc.statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        _infoRow('Document Name', doc.documentName),
                        if (doc.documentType != null &&
                            doc.documentType!.isNotEmpty)
                          _infoRow('Document Type', doc.documentType),
                        if (doc.documentNumber != null &&
                            doc.documentNumber!.isNotEmpty)
                          _infoRow('Document Number', doc.documentNumber),
                        _infoRow('File Format', doc.fileFormatLabel),
                        if (doc.fileSize != null && doc.fileSize!.isNotEmpty)
                          _infoRow('File Size', doc.fileSize),
                        if (doc.formattedUploadDate != null)
                          _infoRow('Uploaded On', doc.formattedUploadDate),
                        if (doc.remarks != null && doc.remarks!.isNotEmpty)
                          _infoRow('Remarks', doc.remarks),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  if (resolvedUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isDownloading ? null : _openOrDownloadDocument,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                doc.isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.open_in_new_rounded,
                              ),
                        label: Text(
                          _isDownloading
                              ? 'Opening Document...'
                              : (doc.isPdf
                                  ? 'Open / View Full PDF'
                                  : 'Open Full Resolution File'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagePreview(String url) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260, maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                headers: _authHeaders,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: _green,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Unable to render image preview directly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the button below to open the file.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Pinch to zoom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreviewCard(BeneficiaryDocumentModel doc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 44,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doc.documentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16231C),
            ),
          ),
          if (doc.documentNumber != null && doc.documentNumber!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              doc.documentNumber!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _statusChip(doc.verificationStatus, doc.statusColor),
          const SizedBox(height: 16),
          Text(
            'PDF Document • ${doc.fileSize ?? 'Ready to view'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericFileCard(BeneficiaryDocumentModel doc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F3E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 44,
              color: _green,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doc.documentName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16231C),
            ),
          ),
          const SizedBox(height: 14),
          _statusChip(doc.verificationStatus, doc.statusColor),
        ],
      ),
    );
  }
}
