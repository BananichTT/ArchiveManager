import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/models/store_item.dart';

class StorageService {
  static const String _storesKey = 'saved_stores';

  Future<void> saveStores(List<StoreItem> stores) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      stores.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_storesKey, encodedData);
  }

  Future<List<StoreItem>> loadStores() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_storesKey);

    if (encodedData != null) {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      return decodedData.map((item) => StoreItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> clearStores() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storesKey);
  }
}
