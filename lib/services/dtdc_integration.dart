import 'dart:convert';
import 'package:http/http.dart' as http;

class DTDCIntegration {
  /// Call the DTDC API with the provided order details.
  /// Replace the URL and payload keys as per DTDC API documentation.
  static Future<bool> integrate(Map<String, dynamic> orderDetails) async {
    final url = Uri.parse(
        'https://api.dtdc.com/shipments'); // update with DTDC's API endpoint
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderDetails),
      );
      if (response.statusCode == 200) {
        // Optionally process the response.
        print('DTDC integration successful: ${response.body}');
        return true;
      } else {
        print(
            'DTDC integration failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during DTDC integration: $e');
      return false;
    }
  }
}
