import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // ✅ Read from environment variable passed via --dart-define
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://esmnst-backend.onrender.com/api',
  );
  
  // Get auth token
  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final String? token = await user.getIdToken();
    if (token == null) throw Exception('Failed to get token');
    return token;
  }

  // Get headers with auth token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Get available countries
  static Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/esim/countries'),  // ✅ Uses baseUrl from environment
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['countries']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching countries: $e');
      return [];
    }
  }

  // Get plans for a country
  static Future<List<Map<String, dynamic>>> getPlans({String? country}) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/esim/plans';
      if (country != null && country.isNotEmpty) {
        url += '?country=$country';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['plans']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching plans: $e');
      return [];
    }
  }

  // Purchase an eSIM
  static Future<Map<String, dynamic>> purchasePlan(String planId, String country) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/esim/purchase'),
        headers: headers,
        body: json.encode({
          'plan_id': planId,
          'country': country,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'error': 'Purchase failed'};
      }
    } catch (e) {
      print('Error purchasing plan: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get provider balance (admin only)
  static Future<Map<String, dynamic>> getProviderBalance() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/esim/provider-balance'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }
}
