import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MenuService {
  static Future<List<dynamic>> getHallMenus(int hallId) async {
    final response = await http.get(Uri.parse('$baseUrl/hall/$hallId/menus'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load menus');
  }

  static Future<Map<String, dynamic>> addMenuItem(int hallId, Map<String, dynamic> menuData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/halls/$hallId/menus'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(menuData),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to add menu item');
  }

  static Future<Map<String, dynamic>> updateMenuItem(int hallId, int menuId, Map<String, dynamic> menuData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/halls/$hallId/menus/$menuId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(menuData),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update menu item');
  }

  static Future<Map<String, dynamic>> deleteMenuItem(int hallId, int menuId) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/halls/$hallId/menus/$menuId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to delete menu item');
  }
}
