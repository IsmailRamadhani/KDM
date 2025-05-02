import 'package:flutter/material.dart';
import 'package:ta_project/itemModel/item_model.dart';
import 'package:ta_project/itemModel/database_helper.dart';

class ItemProvider with ChangeNotifier {
  final DataBaseHelper _dbHelper = DataBaseHelper();
  List<Item> _items = [];
  bool _isLoading = false;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    _items = await _dbHelper.getItems();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await _dbHelper.insertItem(item);
    await loadItems();
  }

  Future<void> updateItem(Item item) async {
    await _dbHelper.updateItem(item);
    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await _dbHelper.deleteItem(id);
    await loadItems();
  }
}
