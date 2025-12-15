class PaymentMethod {
  final String id;
  final String name;
  final String type; // 'online', 'cash'
  final String? qrCodeUrl;
  final String? mobileNumber;
  final String? accountName;
  final String? instructions;
  final bool isActive;
  final DateTime createdAt;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.qrCodeUrl,
    this.mobileNumber,
    this.accountName,
    this.instructions,
    required this.isActive,
    required this.createdAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      qrCodeUrl: json['qr_code_url'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      accountName: json['account_name'] as String?,
      instructions: json['instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'qr_code_url': qrCodeUrl,
      'mobile_number': mobileNumber,
      'account_name': accountName,
      'instructions': instructions,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isOnline => type == 'online';
  bool get isCash => type == 'cash';
}
