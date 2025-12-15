import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'dart:typed_data';
import '../../models/ticket.dart';
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../models/seat.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import 'package:intl/intl.dart';

class TicketScreen extends StatefulWidget {
  final String ticketId;

  const TicketScreen({super.key, required this.ticketId});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  Ticket? _ticket;
  Movie? _movie;
  Showtime? _showtime;
  List<Seat> _seats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTicketData();
  }

  Future<void> _loadTicketData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load ticket
      final ticketResponse = await SupabaseService.tickets
          .select()
          .eq('id', widget.ticketId)
          .single();
      final ticket = Ticket.fromJson(ticketResponse);

      // Load showtime
      final showtimeResponse = await SupabaseService.showtimes
          .select()
          .eq('id', ticket.showtimeId)
          .single();
      final showtime = Showtime.fromJson(showtimeResponse);

      // Load movie
      final movieResponse = await SupabaseService.movies
          .select()
          .eq('id', showtime.movieId)
          .single();
      final movie = Movie.fromJson(movieResponse);

      // Load seats
      final seatsResponse = await SupabaseService.seats.select().inFilter(
        'id',
        ticket.seatIds,
      );
      final seats = (seatsResponse as List)
          .map((json) => Seat.fromJson(json))
          .toList();

      setState(() {
        _ticket = ticket;
        _movie = movie;
        _showtime = showtime;
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Go back to dashboard after viewing ticket
            context.go('/dashboard');
          },
        ),
        title: const Text(
          'Your Ticket',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _downloadTicket,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            )
          : _error != null
          ? _buildErrorState()
          : _buildTicketContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppConstants.primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Failed to load ticket',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loadTicketData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketContent() {
    final seatLabels = _seats.map((s) => s.seatLabel).join(', ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Ticket Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with status badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _ticket!.paymentStatus == PaymentStatus.pending
                            ? 'PENDING TICKET'
                            : 'E-TICKET',
                        style: const TextStyle(
                          color: Color(0xFF808080),
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _ticket!.paymentStatus == PaymentStatus.pending
                              ? 'AWAITING APPROVAL'
                              : _ticket!.status.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pending Payment Banner
                if (_ticket!.paymentStatus == PaymentStatus.pending)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.hourglass_top,
                          color: Colors.orange,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Payment Pending Verification',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your payment is being verified by admin.\nYour ticket will be available once approved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB3B3B3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Rejected Payment Banner
                if (_ticket!.isRejected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        const Text(
                          'Payment Rejected',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reason from Admin:',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _ticket!.rejectionReason ??
                                    'No reason provided',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Resubmit Payment Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showResubmitPaymentDialog,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Resubmit Payment Proof'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload a new screenshot with correct payment details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB3B3B3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Movie Poster
                if (_movie?.posterUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(0),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: _movie!.posterUrl!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 300,
                        color: const Color(0xFF2A2A2A),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Movie Title
                      Text(
                        _movie?.title ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _movie?.language ?? '',
                        style: const TextStyle(
                          color: Color(0xFF808080),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFF2A2A2A)),
                      const SizedBox(height: 24),

                      // Ticket Details Grid
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        DateFormat(
                          'EEEE, MMM d, yyyy',
                        ).format(_showtime!.showtime),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.access_time,
                        'Time',
                        DateFormat('h:mm a').format(_showtime!.showtime),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.location_on,
                        'Cinema',
                        _showtime!.cinemaHall,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.event_seat, 'Seats', seatLabels),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.confirmation_number,
                        'Tickets',
                        '${_seats.length} ${_seats.length == 1 ? 'ticket' : 'tickets'}',
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFF2A2A2A)),
                      const SizedBox(height: 24),

                      // QR Code
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'SCAN QR CODE AT ENTRANCE',
                              style: TextStyle(
                                color: Color(0xFF808080),
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: _ticket!.qrCodeData,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _ticket!.ticketNumber,
                              style: const TextStyle(
                                color: Color(0xFF808080),
                                fontSize: 14,
                                fontFamily: 'Courier',
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFF2A2A2A)),
                      const SizedBox(height: 24),

                      // Payment Details
                      _buildPaymentDetail(
                        'Reference',
                        _ticket!.paymentReference,
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentDetail(
                        'Payment Method',
                        _ticket!.paymentMethod.toUpperCase(),
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentDetail(
                        'Total Amount',
                        '₱${_ticket!.totalAmount.toStringAsFixed(2)}',
                        isHighlighted: true,
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentDetail(
                        'Booked On',
                        DateFormat('MMM d, yyyy h:mm a').format(
                          _ticket!.createdAt.toUtc().add(
                            const Duration(hours: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Important Notes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppConstants.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Important Notes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNote('Please arrive 15 minutes before showtime'),
                _buildNote('Ticket is valid only for the selected showtime'),
                _buildNote('No refunds or exchanges after booking'),
                _buildNote('Outside food and drinks are not allowed'),
                _buildNote('Show this QR code at the entrance'),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppConstants.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF808080), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetail(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? Colors.white : const Color(0xFF808080),
            fontSize: isHighlighted ? 16 : 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? AppConstants.primaryColor : Colors.white,
            fontSize: isHighlighted ? 18 : 14,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Color(0xFF808080), fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF808080),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    // Check payment status first for pending
    if (_ticket!.paymentStatus == PaymentStatus.pending) {
      return Colors.orange;
    }
    switch (_ticket!.status) {
      case TicketStatus.pending:
        return Colors.orange;
      case TicketStatus.active:
      case TicketStatus.confirmed:
        return Colors.green;
      case TicketStatus.used:
        return Colors.blue;
      case TicketStatus.cancelled:
        return Colors.red;
    }
  }

  void _showResubmitPaymentDialog() {
    XFile? selectedImage;
    Uint8List? imageBytes;
    final TextEditingController referenceController = TextEditingController(
      text: _ticket?.paymentReference ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          title: const Text(
            'Resubmit Payment Proof',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload a new screenshot with correct payment details.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Reference Number Field
                TextField(
                  controller: referenceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reference Number',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Enter reference number',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Screenshot Upload Button
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1920,
                      maxHeight: 1920,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setDialogState(() {
                        selectedImage = image;
                        imageBytes = bytes;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: imageBytes != null
                            ? Colors.green
                            : Colors.grey[700]!,
                      ),
                    ),
                    child: imageBytes != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Screenshot selected',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedImage = null;
                                    imageBytes = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'Tap to upload screenshot',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (referenceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reference number'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (selectedImage == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please upload a screenshot'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _resubmitPayment(
                  referenceController.text.trim(),
                  selectedImage!,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resubmitPayment(
    String referenceNumber,
    XFile screenshotFile,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload screenshot
      String? screenshotUrl;
      try {
        final fileBytes = await screenshotFile.readAsBytes();
        final filePath = screenshotFile.path;
        final fileExt = filePath
            .split('.')
            .last
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        final fileName = 'payment_proof_${user.id}_$timestamp.$fileExt';

        String contentType;
        switch (fileExt) {
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'png':
            contentType = 'image/png';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          default:
            contentType = 'image/jpeg';
        }

        await SupabaseService.client.storage
            .from('payment-proofs')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );

        screenshotUrl = SupabaseService.client.storage
            .from('payment-proofs')
            .getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Screenshot upload failed: $e');
      }

      // Update ticket - reset to pending status
      await SupabaseService.client
          .from('tickets')
          .update({
            'payment_status': 'pending',
            'status': 'active',
            'payment_reference': referenceNumber,
            'rejection_reason': null,
            if (screenshotUrl != null) 'payment_proof_url': screenshotUrl,
          })
          .eq('id', _ticket!.id);

      // Reserve the seats again
      for (var seat in _seats) {
        await SupabaseService.client
            .from('seats')
            .update({'status': 'reserved', 'user_id': user.id})
            .eq('id', seat.id);
      }

      // Close loading
      if (mounted) Navigator.pop(context);

      // Reload ticket data
      await _loadTicketData();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment proof resubmitted! Awaiting admin approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resubmit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadTicket() async {
    if (_ticket == null || _movie == null || _showtime == null) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Generate PDF
      final pdfBytes = await _generateTicketPdf();

      // Trigger download / share of the generated PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'ticket_${_ticket!.ticketNumber}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ticket downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generateTicketPdf() async {
    final pdf = pw.Document();

    // Generate QR code data
    final qrCodeData = _ticket!.paymentReference;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'CINEMATE',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Movie Ticket',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 40),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // Movie Details
                pw.Text(
                  _movie!.title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Ticket Information
                _buildPdfRow('Ticket Number', _ticket!.ticketNumber),
                pw.SizedBox(height: 10),
                _buildPdfRow(
                  'Date',
                  DateFormat('EEEE, MMMM d, yyyy').format(_showtime!.showtime),
                ),
                pw.SizedBox(height: 10),
                _buildPdfRow(
                  'Time',
                  DateFormat('h:mm a').format(_showtime!.showtime),
                ),
                pw.SizedBox(height: 10),
                _buildPdfRow('Cinema', _showtime!.cinemaHall),
                pw.SizedBox(height: 10),
                _buildPdfRow(
                  'Seats',
                  _seats.map((s) => s.seatLabel).join(', '),
                ),
                pw.SizedBox(height: 10),
                // Use ASCII currency label for PDF so glyphs render reliably.
                // To render the peso sign (₱) in the PDF, embed a TTF/OTF font that
                // contains the glyph and use `pw.Font.ttf(...)` when drawing text.
                _buildPdfRow(
                  'Total Amount',
                  'PHP ${_ticket!.totalAmount.toStringAsFixed(2)}',
                ),
                pw.SizedBox(height: 10),
                _buildPdfRow(
                  'Payment Method',
                  _ticket!.paymentMethod.toUpperCase(),
                ),

                pw.SizedBox(height: 40),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),

                // QR Code
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Scan at Cinema',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.BarcodeWidget(
                        data: qrCodeData,
                        barcode: pw.Barcode.qrCode(),
                        width: 150,
                        height: 150,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        _ticket!.paymentReference,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Please arrive 15 minutes before showtime',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}
