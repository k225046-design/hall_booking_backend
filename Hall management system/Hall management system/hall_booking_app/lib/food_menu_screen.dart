import 'package:flutter/material.dart';
import 'menu_service.dart';

class FoodMenuScreen extends StatefulWidget {
  final int hallId;
  final String hallName;
  final Function(List<Map<String, dynamic>>, double) onMenuSelected;

  const FoodMenuScreen({
    super.key,
    required this.hallId,
    required this.hallName,
    required this.onMenuSelected,
  });

  @override
  State<FoodMenuScreen> createState() => _FoodMenuScreenState();
}

class _FoodMenuScreenState extends State<FoodMenuScreen> {
  List<Map<String, dynamic>> menus = [];
  Map<int, int> selectedQuantities = {};
  double totalExtraCost = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    try {
      final loadedMenus = await MenuService.getHallMenus(widget.hallId);
      setState(() {
        menus = List<Map<String, dynamic>>.from(loadedMenus);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading menus: $e')));
    }
  }

  void _updateQuantity(int menuId, int quantity) {
    setState(() {
      selectedQuantities[menuId] = quantity;
      totalExtraCost = 0.0;
      for (var entry in selectedQuantities.entries) {
        final menu = menus.firstWhere((m) => m['menu_id'] == entry.key);
        totalExtraCost += menu['price_per_plate'] * entry.value;
      }
    });
  }

  List<Map<String, dynamic>> getSelectedMenus() {
    return selectedQuantities.entries.map((entry) {
      final menu = menus.firstWhere((m) => m['menu_id'] == entry.key);
      return {
        ...menu,
        'quantity': entry.value,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hallName} - Food Menu'),
        actions: [
          Text(
            'PKR ${totalExtraCost.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: menus.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: menus.length,
              itemBuilder: (context, index) {
                final menu = menus[index];
                final quantity = selectedQuantities[menu['menu_id']] ?? 0;
                final itemTotal = menu['price_per_plate'] * quantity;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(menu['item_name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(menu['category']),
                        if (menu['description']?.isNotEmpty == true) Text(menu['description']!),
                        Text('PKR ${menu['price_per_plate']} / plate ${menu['is_vegetarian'] ? '(Veg)' : ''}'),
                        Text('Total: PKR ${itemTotal.toStringAsFixed(0)}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: quantity > 0 ? () => _updateQuantity(menu['menu_id'], quantity - 1) : null,
                        ),
                        Text('$quantity'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _updateQuantity(menu['menu_id'], quantity + 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: totalExtraCost > 0
            ? () {
                widget.onMenuSelected(getSelectedMenus(), totalExtraCost);
                Navigator.pop(context);
              }
            : null,
        label: Text('Select Food (PKR ${totalExtraCost.toStringAsFixed(0)})'),
        icon: const Icon(Icons.restaurant),
      ),
    );
  }
}
