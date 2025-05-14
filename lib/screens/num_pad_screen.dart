import 'package:flutter/material.dart';

class CustomKeypadDemo extends StatefulWidget {
  const CustomKeypadDemo({super.key});

  @override
  _CustomKeypadDemoState createState() => _CustomKeypadDemoState();
}

class _CustomKeypadDemoState extends State<CustomKeypadDemo> {
  // Example: two columns (reps, weight) with 5 rows (sets).
  // Each row has 2 TextControllers: row i => [ repsControllers[i], weightControllers[i] ]
  final List<TextEditingController> repsControllers =
  List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> weightControllers =
  List.generate(5, (_) => TextEditingController());

  final List<FocusNode> repsFocusNodes =
  List.generate(5, (_) => FocusNode());
  final List<FocusNode> weightFocusNodes =
  List.generate(5, (_) => FocusNode());

  // Track which TextField is currently active
  FocusNode? currentFocus;

  @override
  void initState() {
    super.initState();
    // Attach listeners to all focus nodes
    for (var node in repsFocusNodes) {
      node.addListener(_handleFocusChange);
    }
    for (var node in weightFocusNodes) {
      node.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    // If a focus node gained focus, store it as currentFocus
    setState(() {
      currentFocus = repsFocusNodes.firstWhere(
            (node) => node.hasFocus,
        orElse: () => weightFocusNodes.firstWhere(
              (node) => node.hasFocus,
          orElse: () => FocusNode(),
        ),
      );
    });
  }

  // Identify which field is active so we know which controller to update
  TextEditingController? getActiveController() {
    for (int i = 0; i < 5; i++) {
      if (repsFocusNodes[i] == currentFocus) {
        return repsControllers[i];
      }
      if (weightFocusNodes[i] == currentFocus) {
        return weightControllers[i];
      }
    }
    return null;
  }

  // Example: Move focus down in the same column
  void _moveFocusDown() {
    for (int i = 0; i < 5; i++) {
      if (repsFocusNodes[i] == currentFocus) {
        // If not the last row, move to next row's reps
        if (i < 4) repsFocusNodes[i + 1].requestFocus();
        return;
      }
      if (weightFocusNodes[i] == currentFocus) {
        // If not the last row, move to next row's weight
        if (i < 4) weightFocusNodes[i + 1].requestFocus();
        return;
      }
    }
  }

  // Example: Move focus right (from reps to weight in the same row)
  void _moveFocusRight() {
    for (int i = 0; i < 5; i++) {
      if (repsFocusNodes[i] == currentFocus) {
        weightFocusNodes[i].requestFocus();
        return;
      }
    }
  }

  // Auto-fill the column with the same value
  void _autoFillColumn() {
    final controller = getActiveController();
    if (controller == null) return;

    final value = controller.text;
    // Check if the active field is in reps or weight
    final isReps = repsControllers.contains(controller);

    if (isReps) {
      // Fill all repsControllers
      for (var c in repsControllers) {
        c.text = value;
      }
    } else {
      // Fill all weightControllers
      for (var c in weightControllers) {
        c.text = value;
      }
    }
  }

  void _onKeyTap(String keyValue) {
    final controller = getActiveController();
    if (controller == null) return;

    // Example: just append the tapped value
    controller.text += keyValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Custom Keypad Example")),
      body: Column(
        children: [
          // Display your input fields in a table
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: repsControllers[index],
                        focusNode: repsFocusNodes[index],
                        readOnly: true,
                        decoration: InputDecoration(labelText: "Reps ${index + 1}"),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: weightControllers[index],
                        focusNode: weightFocusNodes[index],
                        readOnly: true,
                        decoration: InputDecoration(labelText: "Weight ${index + 1}"),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Your custom keypad at the bottom
          Container(
            color: Colors.grey[200],
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Row 1: 1, 2, 3
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("1"),
                    _buildKey("2"),
                    _buildKey("3"),
                    _buildFunctionKey("⌫", () {
                      final controller = getActiveController();
                      if (controller != null && controller.text.isNotEmpty) {
                        controller.text =
                            controller.text.substring(0, controller.text.length - 1);
                      }
                    }),
                  ],
                ),
                // Row 2: 4, 5, 6
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("4"),
                    _buildKey("5"),
                    _buildKey("6"),
                    _buildFunctionKey("Done", () {
                      // Possibly unfocus all
                      FocusScope.of(context).unfocus();
                    }),
                  ],
                ),
                // Row 3: 7, 8, 9
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("7"),
                    _buildKey("8"),
                    _buildKey("9"),
                    _buildFunctionKey("→", _moveFocusRight),
                  ],
                ),
                // Row 4: <<, 0, .
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFunctionKey("↓↓", _autoFillColumn),
                    _buildKey("0"),
                    _buildKey("."),
                    _buildFunctionKey("↓", _moveFocusDown),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return ElevatedButton(
      onPressed: () => _onKeyTap(label),
      child: Text(label),
    );
  }

  Widget _buildFunctionKey(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
