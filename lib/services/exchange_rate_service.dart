import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching real-time exchange rates
/// Uses bank buying rates (slightly worse than exact exchange rate for customer)
class ExchangeRateService {
  static const String _apiUrl = 'https://api.exchangerate-api.com/v4/latest/USD';
  
  /// Fetch current exchange rates from USD to other currencies
  /// Returns bank buying rates (adjusted to be slightly worse for customer)
  static Future<Map<String, double>> fetchBankBuyingRates() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = (data['rates'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        // Apply bank buying rate adjustment (typically 2-3% worse than exact rate)
        // This simulates the bank's margin
        final bankRates = <String, double>{};
        rates.forEach((currency, rate) {
          // For currencies worth more than USD (rate < 1), add the margin
          // For currencies worth less than USD (rate > 1), multiply by margin
          if (rate < 1) {
            bankRates[currency] = rate * 0.97; // 3% worse for customer
          } else {
            bankRates[currency] = rate * 1.03; // 3% worse for customer
          }
        });

        return bankRates;
      } else {
        throw Exception('Failed to fetch exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exchange rates: $e');
    }
  }

  /// Fetch a specific currency rate
  static Future<double> fetchBankBuyingRate(String currencyCode) async {
    final rates = await fetchBankBuyingRates();
    return rates[currencyCode] ?? 1.0;
  }

  /// Get preset currencies with current bank buying rates
  static Future<List<Map<String, String>>> getPresetsWithLiveRates() async {
    try {
      final rates = await fetchBankBuyingRates();
      
      return [
        {'c': 'USD', 's': '\$', 'r': '1.0', 'd': '2', 'n': 'US Dollar'},
        {'c': 'NIO', 's': 'C\$', 'r': (rates['NIO'] ?? 36.6).toStringAsFixed(4), 'd': '2', 'n': 'Nicaraguan Córdoba'},
        {'c': 'EUR', 's': '€', 'r': (rates['EUR'] ?? 0.92).toStringAsFixed(4), 'd': '2', 'n': 'Euro'},
        {'c': 'CAD', 's': 'C\$', 'r': (rates['CAD'] ?? 1.35).toStringAsFixed(4), 'd': '2', 'n': 'Canadian Dollar'},
        {'c': 'GBP', 's': '£', 'r': (rates['GBP'] ?? 0.78).toStringAsFixed(4), 'd': '2', 'n': 'British Pound'},
        {'c': 'JPY', 's': '¥', 'r': (rates['JPY'] ?? 145.0).toStringAsFixed(4), 'd': '0', 'n': 'Japanese Yen'},
        {'c': 'CRC', 's': '₡', 'r': (rates['CRC'] ?? 515.0).toStringAsFixed(4), 'd': '0', 'n': 'Costa Rican Colón'},
        {'c': 'MXN', 's': '\$', 'r': (rates['MXN'] ?? 17.5).toStringAsFixed(4), 'd': '2', 'n': 'Mexican Peso'},
        {'c': 'AUD', 's': 'A\$', 'r': (rates['AUD'] ?? 1.52).toStringAsFixed(4), 'd': '2', 'n': 'Australian Dollar'},
        {'c': 'CHF', 's': 'Fr', 'r': (rates['CHF'] ?? 0.88).toStringAsFixed(4), 'd': '2', 'n': 'Swiss Franc'},
        {'c': 'CNY', 's': '¥', 'r': (rates['CNY'] ?? 7.2).toStringAsFixed(4), 'd': '2', 'n': 'Chinese Yuan'},
        {'c': 'BRL', 's': 'R\$', 'r': (rates['BRL'] ?? 5.0).toStringAsFixed(4), 'd': '2', 'n': 'Brazilian Real'},
      ];
    } catch (e) {
      // Return fallback rates if API fails
      return [
        {'c': 'USD', 's': '\$', 'r': '1.0', 'd': '2', 'n': 'US Dollar'},
        {'c': 'NIO', 's': 'C\$', 'r': '36.6', 'd': '2', 'n': 'Nicaraguan Córdoba'},
        {'c': 'EUR', 's': '€', 'r': '0.92', 'd': '2', 'n': 'Euro'},
        {'c': 'CAD', 's': 'C\$', 'r': '1.35', 'd': '2', 'n': 'Canadian Dollar'},
        {'c': 'GBP', 's': '£', 'r': '0.78', 'd': '2', 'n': 'British Pound'},
        {'c': 'JPY', 's': '¥', 'r': '145.0', 'd': '0', 'n': 'Japanese Yen'},
        {'c': 'CRC', 's': '₡', 'r': '515.0', 'd': '0', 'n': 'Costa Rican Colón'},
        {'c': 'MXN', 's': '\$', 'r': '17.5', 'd': '2', 'n': 'Mexican Peso'},
        {'c': 'AUD', 's': 'A\$', 'r': '1.52', 'd': '2', 'n': 'Australian Dollar'},
        {'c': 'CHF', 's': 'Fr', 'r': '0.88', 'd': '2', 'n': 'Swiss Franc'},
        {'c': 'CNY', 's': '¥', 'r': '7.2', 'd': '2', 'n': 'Chinese Yuan'},
        {'c': 'BRL', 's': 'R\$', 'r': '5.0', 'd': '2', 'n': 'Brazilian Real'},
      ];
    }
  }
}
