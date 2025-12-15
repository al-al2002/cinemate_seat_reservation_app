import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cineme_seat_reservation_app/models/payment_method.dart';
import 'package:cineme_seat_reservation_app/services/payment_service.dart';
import 'package:cineme_seat_reservation_app/services/supabase_service.dart';
import 'package:cineme_seat_reservation_app/screens/payment/payment_confirmation_screen.dart';

class PaymentSelectionScreen extends StatefulWidget {
  final String showtimeId;
  final List<String> seatIds;
  final List<String> seatNumbers;
  final double totalAmount;
  final String movieTitle;
  final DateTime showtimeDate;
  final String cinemaHall;

  const PaymentSelectionScreen({
    super.key,
    required this.showtimeId,
    required this.seatIds,
    required this.seatNumbers,
    required this.totalAmount,
    required this.movieTitle,
    required this.showtimeDate,
    required this.cinemaHall,
  });

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true;
  String? _error;
  PaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await PaymentService.getPaymentMethods();
      setState(() {
        _paymentMethods = methods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showPaymentMethodModal(PaymentMethod method) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentMethodModal(
        paymentMethod: method,
        totalAmount: widget.totalAmount,
        onProceed: () {
          Navigator.pop(context);
          _proceedWithPayment(method);
        },
      ),
    );
  }

  Future<void> _proceedWithPayment(PaymentMethod method) async {
    // Get current user ID
    final userId = SupabaseService.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create pending ticket with payment reservation
      final ticket = await PaymentService.createPendingTicket(
        userId: userId,
        showtimeId: widget.showtimeId,
        seatIds: widget.seatIds,
        totalAmount: widget.totalAmount,
        paymentMethodId: method.id,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to confirmation screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentConfirmationScreen(
              ticket: ticket,
              paymentMethod: method,
              movieTitle: widget.movieTitle,
              showtimeDate: widget.showtimeDate,
              cinemaHall: widget.cinemaHall,
              seatNumbers: widget.seatNumbers,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create reservation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Payment Method'),
        backgroundColor: const Color(0xFFE50914),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPaymentMethods,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking Summary
                  _buildBookingSummary(),
                  const SizedBox(height: 24),

                  // Payment Methods
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment method cards
                  ..._paymentMethods.map((method) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPaymentMethodCard(method),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.movieTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow(
            Icons.event,
            'Date',
            '${widget.showtimeDate.day}/${widget.showtimeDate.month}/${widget.showtimeDate.year} ${widget.showtimeDate.hour}:${widget.showtimeDate.minute.toString().padLeft(2, '0')}',
          ),
          _summaryRow(Icons.location_on, 'Hall', widget.cinemaHall),
          _summaryRow(Icons.event_seat, 'Seats', widget.seatNumbers.join(', ')),
          const Divider(color: Colors.grey),
          _summaryRow(
            Icons.payment,
            'Total',
            '₱${widget.totalAmount.toStringAsFixed(2)}',
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? const Color(0xFFE50914) : Colors.white,
                fontSize: isHighlighted ? 18 : 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    return InkWell(
      onTap: () => _showPaymentMethodModal(method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedMethod?.id == method.id
                ? const Color(0xFFE50914)
                : Colors.grey[800]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon based on type
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: method.isOnline ? Colors.blue[900] : Colors.green[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                method.isOnline ? Icons.qr_code : Icons.money,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Method details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (method.isOnline && method.mobileNumber != null)
                    Text(
                      method.mobileNumber!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                ],
              ),
            ),

            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

// Payment Method Modal
class _PaymentMethodModal extends StatelessWidget {
  final PaymentMethod paymentMethod;
  final double totalAmount;
  final VoidCallback onProceed;

  const _PaymentMethodModal({
    required this.paymentMethod,
    required this.totalAmount,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                paymentMethod.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QR Code (for online payments)
          if (paymentMethod.isOnline && paymentMethod.qrCodeUrl != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                paymentMethod.qrCodeUrl!,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.qr_code, size: 200);
                },
              ),
            ),

          if (paymentMethod.isOnline) const SizedBox(height: 16),

          // Mobile Number (for online payments)
          if (paymentMethod.isOnline && paymentMethod.mobileNumber != null)
            _buildInfoCard(
              'Mobile Number',
              paymentMethod.mobileNumber!,
              Icons.phone,
              () {
                Clipboard.setData(
                  ClipboardData(text: paymentMethod.mobileNumber!),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mobile number copied!')),
                );
              },
            ),

          // Account Name
          if (paymentMethod.accountName != null)
            _buildInfoCard(
              'Account Name',
              paymentMethod.accountName!,
              Icons.person,
              null,
            ),

          const SizedBox(height: 16),

          // Amount to Pay
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount to Pay:',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  '₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          if (paymentMethod.instructions != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    paymentMethod.instructions!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Proceed Button
          ElevatedButton(
            onPressed: onProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Proceed to Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.copy, color: Colors.blue),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}
