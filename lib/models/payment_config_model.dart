class PaymentConfig {
  final bool bacEnabled;
  final String bacApiKey; // Mock placeholder
  final bool paypalEnabled;
  final String paypalClientId;
  final String paypalSecret;
  final double taxRate; // 0.15 for 15%
  final double dineInServiceFeeRate; // 0.10 for 10%
  
  const PaymentConfig({
    this.bacEnabled = true,
    this.bacApiKey = 'msg_mock_bac_key_123',
    this.paypalEnabled = true,
    this.paypalClientId = 'mock_paypal_client_id',
    this.paypalSecret = 'mock_paypal_secret',
    this.taxRate = 0.15,
    this.dineInServiceFeeRate = 0.10,
  });

  factory PaymentConfig.fromMap(Map<String, dynamic> map) {
    return PaymentConfig(
      bacEnabled: map['bacEnabled'] ?? true,
      bacApiKey: map['bacApiKey'] ?? 'msg_mock_bac_key_123',
      paypalEnabled: map['paypalEnabled'] ?? true,
      paypalClientId: map['paypalClientId'] ?? '',
      paypalSecret: map['paypalSecret'] ?? '',
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 0.15,
      dineInServiceFeeRate: (map['dineInServiceFeeRate'] as num?)?.toDouble() ?? 0.10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bacEnabled': bacEnabled,
      'bacApiKey': bacApiKey,
      'paypalEnabled': paypalEnabled,
      'paypalClientId': paypalClientId,
      'paypalSecret': paypalSecret,
      'taxRate': taxRate,
      'dineInServiceFeeRate': dineInServiceFeeRate,
    };
  }
}
