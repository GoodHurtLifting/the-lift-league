import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WidgetPickerBottomSheet extends StatefulWidget {
  final String userId;
  final List<String> currentLayout;
  final Map<String, String> availableWidgets;

  const WidgetPickerBottomSheet({
    super.key,
    required this.userId,
    required this.currentLayout,
    required this.availableWidgets,
  });

  @override
  State<WidgetPickerBottomSheet> createState() => _WidgetPickerBottomSheetState();
}

class _PickerItem {
  String id;
  bool enabled;
  _PickerItem({required this.id, required this.enabled});
}

class _WidgetPickerBottomSheetState extends State<WidgetPickerBottomSheet> {
  late List<_PickerItem> _items;

  @override
  void initState() {
    super.initState();
    final enabledSet = widget.currentLayout.toSet();
    final remaining = widget.availableWidgets.keys
        .where((id) => !enabledSet.contains(id))
        .toList();
    _items = [
      ...widget.currentLayout.map((id) => _PickerItem(id: id, enabled: true)),
      ...remaining.map((id) => _PickerItem(id: id, enabled: false)),
    ];
  }

  Future<void> _save() async {
    final layout = _items.where((e) => e.enabled).map((e) => e.id).toList();
    try {
      await FirebaseFirestore.instance
          .doc('users/${widget.userId}/preferences')
          .set({'statsLayout': layout}, SetOptions(merge: true));
      if (mounted) Navigator.pop(context, layout);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              children: [
                for (final item in _items)
                  ListTile(
                    key: ValueKey(item.id),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(widget.availableWidgets[item.id] ?? item.id),
                    trailing: Switch(
                      value: item.enabled,
                      onChanged: (val) {
                        setState(() {
                          item.enabled = val;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

