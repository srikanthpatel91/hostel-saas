import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Allows owner/chef to define recipes (Bill of Materials):
/// each recipe maps meal name → list of {ingredient, quantity, unit}.
class RecipeBomScreen extends StatefulWidget {
  final String hostelId;
  const RecipeBomScreen({super.key, required this.hostelId});

  @override
  State<RecipeBomScreen> createState() => _RecipeBomScreenState();
}

class _RecipeBomScreenState extends State<RecipeBomScreen> {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection('hostels').doc(widget.hostelId).collection('recipes');

  CollectionReference<Map<String, dynamic>> get _inventory =>
      _db.collection('hostels').doc(widget.hostelId).collection('inventory');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes & BOM'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecipeSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Recipe'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _recipes.orderBy('name').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState(onAdd: () => _showRecipeSheet(context));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              return _RecipeCard(
                doc: doc,
                onEdit: () => _showRecipeSheet(context, doc: doc),
                onDelete: () => _delete(doc.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recipe?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _recipes.doc(id).delete();
  }

  void _showRecipeSheet(BuildContext context, {DocumentSnapshot<Map<String, dynamic>>? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecipeSheet(
        hostelId: widget.hostelId,
        inventory: _inventory,
        recipes: _recipes,
        existing: doc,
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit, onDelete;
  const _RecipeCard({required this.doc, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final d = doc.data()!;
    final name = d['name'] as String? ?? '';
    final mealType = d['mealType'] as String? ?? 'lunch';
    final ingredients = (d['ingredients'] as List<dynamic>?) ?? [];
    final servings = (d['servings'] as num?)?.toInt() ?? 1;

    Color mealColor(String t) {
      switch (t) {
        case 'breakfast': return Colors.orange;
        case 'dinner': return Colors.indigo;
        default: return Colors.green;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(mealType.capitalize(), mealColor(mealType)),
                          const SizedBox(width: 6),
                          _Chip('$servings servings', Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
              ],
            ),
            if (ingredients.isNotEmpty) ...[
              const Divider(height: 16),
              Text('Ingredients (per $servings servings)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ingredients.map((e) {
                  final ing = e as Map<String, dynamic>;
                  return Chip(
                    label: Text('${ing['name']} — ${ing['qty']} ${ing['unit']}',
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecipeSheet extends StatefulWidget {
  final String hostelId;
  final CollectionReference<Map<String, dynamic>> inventory;
  final CollectionReference<Map<String, dynamic>> recipes;
  final DocumentSnapshot<Map<String, dynamic>>? existing;
  const _RecipeSheet({required this.hostelId, required this.inventory, required this.recipes, this.existing});

  @override
  State<_RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends State<_RecipeSheet> {
  final _nameCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController(text: '20');
  String _mealType = 'lunch';
  final List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _invItems = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    final d = widget.existing?.data();
    if (d != null) {
      _nameCtrl.text = d['name'] ?? '';
      _servingsCtrl.text = '${d['servings'] ?? 20}';
      _mealType = d['mealType'] ?? 'lunch';
      final ings = (d['ingredients'] as List<dynamic>?) ?? [];
      _ingredients.addAll(ings.map((e) => Map<String, dynamic>.from(e as Map)));
    }
  }

  Future<void> _loadInventory() async {
    final snap = await widget.inventory.get();
    setState(() {
      _invItems = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, 'name': data['name'] ?? '', 'unit': data['unit'] ?? 'kg'};
      }).toList();
    });
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (_) => _IngredientDialog(
        invItems: _invItems,
        onAdd: (ing) => setState(() => _ingredients.add(ing)),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter recipe name and at least one ingredient')),
      );
      return;
    }
    setState(() => _saving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'mealType': _mealType,
      'servings': int.tryParse(_servingsCtrl.text) ?? 20,
      'ingredients': _ingredients,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (widget.existing != null) {
      await widget.recipes.doc(widget.existing!.id).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await widget.recipes.add(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'New Recipe' : 'Edit Recipe',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Dish Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mealType,
                    decoration: const InputDecoration(labelText: 'Meal Type', border: OutlineInputBorder()),
                    items: ['breakfast', 'lunch', 'dinner']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.capitalize())))
                        .toList(),
                    onChanged: (v) => setState(() => _mealType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _servingsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Servings', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ingredients (${_ingredients.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._ingredients.asMap().entries.map((e) => ListTile(
              dense: true,
              title: Text('${e.value['name']}'),
              subtitle: Text('${e.value['qty']} ${e.value['unit']}'),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _ingredients.removeAt(e.key)),
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientDialog extends StatefulWidget {
  final List<Map<String, dynamic>> invItems;
  final ValueChanged<Map<String, dynamic>> onAdd;
  const _IngredientDialog({required this.invItems, required this.onAdd});

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  String? _selectedId;
  String _selectedName = '', _selectedUnit = 'kg';
  final _qtyCtrl = TextEditingController();
  final _manualNameCtrl = TextEditingController();
  bool _manual = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Ingredient'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.invItems.isNotEmpty && !_manual)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'From Inventory', border: OutlineInputBorder()),
              items: widget.invItems.map((i) => DropdownMenuItem(
                value: i['id'] as String,
                child: Text(i['name'] as String),
              )).toList(),
              onChanged: (v) {
                final item = widget.invItems.firstWhere((i) => i['id'] == v);
                setState(() {
                  _selectedId = v;
                  _selectedName = item['name'] as String;
                  _selectedUnit = item['unit'] as String;
                });
              },
            ),
          if (!_manual) TextButton(
            onPressed: () => setState(() { _manual = true; }),
            child: const Text('Enter manually'),
          ),
          if (_manual) TextField(
            controller: _manualNameCtrl,
            decoration: const InputDecoration(labelText: 'Ingredient Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity (${_manual ? 'units' : _selectedUnit})',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _manual ? _manualNameCtrl.text.trim() : _selectedName;
            final qty = double.tryParse(_qtyCtrl.text) ?? 0;
            if (name.isEmpty || qty <= 0) return;
            widget.onAdd({
              'id': _selectedId ?? '',
              'name': name,
              'qty': qty,
              'unit': _manual ? 'units' : _selectedUnit,
            });
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No recipes yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add First Recipe'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

extension _StrExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
