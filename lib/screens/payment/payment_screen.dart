import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../models/movie.dart';
import '../../models/showtime.dart';
import '../../models/seat.dart';
import '../../services/supabase_service.dart';
import '../../constants/app_constants.dart';
import 'package:intl/intl.dart';

enum PaymentMethod { gcash, maya }

class PaymentScreen extends StatefulWidget {
  final String showtimeId;
  final List<String> selectedSeatIds;

  const PaymentScreen({
    super.key,
    required this.showtimeId,
    required this.selectedSeatIds,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Showtime? _showtime;
  Movie? _movie;
  List<Seat> _seats = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  PaymentMethod? _selectedPaymentMethod;

  // Form controllers
  final _gcashNumberController = TextEditingController();
  final _mayaNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _gcashNumberController.dispose();
    _mayaNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load showtime
      final showtimeResponse = await SupabaseService.showtimes
          .select()
          .eq('id', widget.showtimeId)
          .single();
      final showtime = Showtime.fromJson(showtimeResponse);

      // Check if showtime has already started
      final now = DateTime.now();
      if (showtime.showtime.isBefore(now) ||
          showtime.showtime.isAtSameMomentAs(now)) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This showtime has already started and cannot be booked',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Load movie
      final movieResponse = await SupabaseService.movies
          .select()
          .eq('id', showtime.movieId)
          .single();
      final movie = Movie.fromJson(movieResponse);

      // Load selected seats
      final seatsResponse = await SupabaseService.seats.select().inFilter(
        'id',
        widget.selectedSeatIds,
      );
      final seats = (seatsResponse as List)
          .map((json) => Seat.fromJson(json))
          .toList();

      setState(() {
        _showtime = showtime;
        _movie = movie;
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

  double _calculateTotal() {
    if (_showtime == null) return 0.0;
    double total = 0.0;
    for (var seat in _seats) {
      double seatPrice = _showtime!.basePrice;
      if (seat.seatType == SeatType.vip) {
        seatPrice += 100;
      } else if (seat.seatType == SeatType.premium) {
        seatPrice += 50;
      }
      total += seatPrice;
    }
    return total;
  }

  double _calculateConvenienceFee() {
    return _calculateTotal() * 0.05; // 5% convenience fee
  }

  double _calculateGrandTotal() {
    return _calculateTotal() + _calculateConvenienceFee();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      _showError('Please select a payment method');
      return;
    }

    // Check if showtime has already started
    if (_showtime != null) {
      final now = DateTime.now();
      if (_showtime!.showtime.isBefore(now) ||
          _showtime!.showtime.isAtSameMomentAs(now)) {
        _showError('This showtime has already started and cannot be booked');
        Navigator.of(context).pop();
        return;
      }
    }

    // For GCash and Maya, show QR code payment dialog
    if (_selectedPaymentMethod == PaymentMethod.gcash ||
        _selectedPaymentMethod == PaymentMethod.maya) {
      _showQRPaymentDialog();
      return;
    }
  }

  void _showQRPaymentDialog() {
    final isGCash = _selectedPaymentMethod == PaymentMethod.gcash;
    final paymentName = isGCash ? 'GCash' : 'Maya';
    final paymentNumber = isGCash ? '0917-123-4567' : '0918-765-4321';
    final paymentColor = isGCash
        ? const Color(0xFF007DFE)
        : const Color(0xFF52B848);
    final amount = _calculateGrandTotal();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: paymentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isGCash ? Icons.account_balance_wallet : Icons.payments,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pay with $paymentName',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Code - Scannable
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: QrImageView(
                          data:
                              'https://pay.$paymentName.ph/${paymentNumber.replaceAll('-', '')}?amount=${amount.toStringAsFixed(2)}&name=CINEMATE',
                          version: QrVersions.auto,
                          size: 180,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: paymentColor,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: paymentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan to Pay',
                        style: TextStyle(
                          color: paymentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Or send to number
                const Text(
                  'Or send payment to:',
                  style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        paymentNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: paymentNumber.replaceAll('-', ''),
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Number copied!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Account Name: CINEMATE PH',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // Amount to pay
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: paymentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: paymentColor),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Amount to Pay',
                        style: TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: paymentColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Instructions:',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Scan QR code or send to the number above\n'
                        '2. Pay the exact amount\n'
                        '3. Note your reference number\n'
                        '4. Click "I\'ve Paid" below',
                        style: TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showReferenceInputDialog(paymentName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: paymentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("I've Paid"),
          ),
        ],
      ),
    );
  }

  void _showReferenceInputDialog(String paymentMethod) {
    final referenceController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    XFile? selectedImage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Payment Proof',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter reference number from your payment:',
                    style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g., 1234567890123',
                      hintStyle: const TextStyle(color: Color(0xFF808080)),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.receipt_long,
                        color: Color(0xFF808080),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Upload payment screenshot:',
                    style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Screenshot upload area
                  GestureDetector(
                    onTap: () async {
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 80,
                      );
                      if (image != null) {
                        setDialogState(() {
                          selectedImage = image;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: selectedImage != null ? 200 : 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedImage != null
                              ? Colors.green
                              : const Color(0xFF404040),
                          width: 2,
                        ),
                      ),
                      child: selectedImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: kIsWeb
                                      ? Image.network(
                                          selectedImage!.path,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(selectedImage!.path),
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedImage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Screenshot attached',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Colors.grey[600],
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to upload screenshot',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This helps admin verify your payment',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Screenshot helps admin quickly verify your payment',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (referenceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reference number'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (selectedImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please upload a payment screenshot'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _submitPendingPayment(
                  paymentMethod,
                  referenceController.text,
                  screenshotFile: selectedImage,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPendingPayment(
    String paymentMethod,
    String referenceNumber, {
    XFile? screenshotFile,
  }) async {
    setState(() => _isProcessing = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate a pending ticket number
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ticketNumber = 'TKT-$timestamp';

      // Upload screenshot to Supabase Storage if provided
      String? screenshotUrl;
      if (screenshotFile != null) {
        try {
          final fileBytes = await screenshotFile.readAsBytes();
          final filePath = screenshotFile.path;
          final fileExt = filePath
              .split('.')
              .last
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          final fileName = 'payment_proof_${user.id}_$timestamp.$fileExt';

          // Determine proper content type
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
              contentType = 'image/jpeg'; // Default to jpeg
          }

          await SupabaseService.client.storage
              .from('payment-proofs')
              .uploadBinary(
                fileName,
                fileBytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: true,
                ),
              );

          screenshotUrl = SupabaseService.client.storage
              .from('payment-proofs')
              .getPublicUrl(fileName);
        } catch (e) {
          // Continue without screenshot if upload fails
          debugPrint('Screenshot upload failed: $e');
        }
      }

      // Update seats to reserved status (will be changed to 'paid' when admin approves)
      for (var seat in _seats) {
        await SupabaseService.seats
            .update({'status': 'reserved', 'user_id': user.id})
            .eq('id', seat.id);
      }

      // Create ticket record with pending status
      final ticketData = {
        'user_id': user.id,
        'showtime_id': widget.showtimeId,
        'seat_ids': widget.selectedSeatIds,
        'total_amount': _calculateGrandTotal(),
        'payment_method': paymentMethod.toLowerCase(),
        'payment_reference': referenceNumber,
        'ticket_number': ticketNumber,
        'status': 'active', // Use 'active' for database constraint
        'payment_status': 'pending', // Mark as pending payment approval
        'qr_code_data': ticketNumber,
        if (screenshotUrl != null) 'payment_proof_url': screenshotUrl,
      };

      await SupabaseService.tickets.insert(ticketData);

      // Delete any existing reservation
      await SupabaseService.reservations
          .delete()
          .eq('user_id', user.id)
          .eq('showtime_id', widget.showtimeId)
          .eq('status', 'pending');

      setState(() => _isProcessing = false);

      if (mounted) {
        _showPendingSuccessDialog(referenceNumber);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Failed to submit payment: ${e.toString()}');
    }
  }

  void _showPendingSuccessDialog(String referenceNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top,
                color: Colors.orange,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Submitted!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your payment is pending verification by admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Reference Number',
                    style: TextStyle(color: Color(0xFF808080), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    referenceNumber,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your ticket will be generated once admin verifies your payment.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/my-tickets');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('View My Tickets'),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            )
          : _error != null
          ? _buildErrorState()
          : _buildContent(),
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
            'Failed to load booking details',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: 120,
          ), // Increased padding for bottom bar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary
              _buildBookingSummary(),
              const SizedBox(height: 24),

              // Payment Methods
              _buildPaymentMethods(),
              const SizedBox(height: 24),

              // Payment Details Form
              if (_selectedPaymentMethod != null) _buildPaymentForm(),

              const SizedBox(height: 24), // Extra spacing at bottom
            ],
          ),
        ),

        // Bottom Pay Button
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBookingSummary() {
    final seatNumbers = _seats.map((s) => s.seatLabel).join(', ');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Movie Info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _movie?.posterUrl ?? '',
                  width: 60,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 90,
                      color: const Color(0xFF2A2A2A),
                      child: const Icon(Icons.movie, color: Colors.white),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _movie?.title ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        'MMM d, yyyy • h:mm a',
                      ).format(_showtime!.showtime),
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _showtime!.cinemaHall,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(color: Color(0xFF2A2A2A), height: 32),

          // Seats
          _buildSummaryRow('Seats', seatNumbers),
          const SizedBox(height: 8),
          _buildSummaryRow('Number of Tickets', '${_seats.length}'),

          const Divider(color: Color(0xFF2A2A2A), height: 32),

          // Price Breakdown
          _buildSummaryRow(
            'Subtotal',
            '₱${_calculateTotal().toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Convenience Fee (5%)',
            '₱${_calculateConvenienceFee().toStringAsFixed(2)}',
          ),

          const Divider(color: Color(0xFF2A2A2A), height: 32),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₱${_calculateGrandTotal().toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Payment Method',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // GCash
          _buildPaymentMethodCard(
            PaymentMethod.gcash,
            'GCash',
            'Pay with GCash wallet',
            Icons.account_balance_wallet,
            const Color(0xFF007DFF),
          ),
          const SizedBox(height: 12),

          // Maya
          _buildPaymentMethodCard(
            PaymentMethod.maya,
            'Maya',
            'Pay with Maya (PayMaya)',
            Icons.wallet,
            const Color(0xFF00D632),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedPaymentMethod == method;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A2A2A),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB3B3B3),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedPaymentMethod == PaymentMethod.gcash)
            _buildGCashForm()
          else if (_selectedPaymentMethod == PaymentMethod.maya)
            _buildMayaForm(),
        ],
      ),
    );
  }

  Widget _buildGCashForm() {
    return Column(
      children: [
        TextField(
          controller: _gcashNumberController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            labelText: 'GCash Mobile Number',
            labelStyle: const TextStyle(color: Color(0xFF808080)),
            hintText: '09XXXXXXXXX',
            hintStyle: const TextStyle(color: Color(0xFF404040)),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF007DFF)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF007DFF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF007DFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF007DFF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You will receive a payment request on your GCash app',
                  style: TextStyle(color: Color(0xFF007DFF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMayaForm() {
    return Column(
      children: [
        TextField(
          controller: _mayaNumberController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            labelText: 'Maya Mobile Number',
            labelStyle: const TextStyle(color: Color(0xFF808080)),
            hintText: '09XXXXXXXXX',
            hintStyle: const TextStyle(color: Color(0xFF404040)),
            prefixIcon: const Icon(Icons.phone, color: Color(0xFF00D632)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00D632), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00D632).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF00D632), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Redirecting to Maya app for payment confirmation',
                  style: TextStyle(color: Color(0xFF00D632), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2A2A2A),
              disabledForegroundColor: const Color(0xFF808080),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Pay ₱${_calculateGrandTotal().toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
