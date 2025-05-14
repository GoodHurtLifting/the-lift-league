import 'package:flutter/material.dart';

class NumpadModal extends StatelessWidget {
  final Function(String) onKeyPressed;

  const NumpadModal({super.key, required this.onKeyPressed});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3', 'backspace'],
      ['4', '5', '6', 'done'],
      ['7', '8', '9', 'decimal'],
      ['fillDown', '0', 'arrowDown', 'arrowRight'],
    ];

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.only(bottom: 10),
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 16,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.7,
              ),
              itemBuilder: (context, index) {
                final row = index ~/ 4;
                final col = index % 4;
                final keyLabel = keys[row][col];

                Icon? icon;
                String? displayText;
                switch (keyLabel) {
                  case 'backspace':
                    icon = const Icon(Icons.backspace);
                    break;
                  case 'done':
                    icon = const Icon(Icons.check_circle);
                    break;
                  case 'decimal':
                    displayText = '.';
                    break;
                  case 'fillDown':
                    icon = const Icon(Icons.keyboard_double_arrow_down);
                    break;
                  case 'arrowDown':
                    icon = const Icon(Icons.arrow_downward);
                    break;
                  case 'arrowRight':
                    icon = const Icon(Icons.arrow_forward);
                    break;
                  default:
                    displayText = keyLabel;
                }

                return GestureDetector(
                  onTap: () => onKeyPressed(keyLabel),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: icon ??
                          Text(
                            displayText ?? '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
