import 'package:flutter/material.dart';

class IconPicker extends StatelessWidget {
  final String selectedIcon;
  final ValueChanged<String> onIconSelected;
  final List<IconData> icons;
  final List<String> iconNames;

  IconPicker({
    required this.selectedIcon,
    required this.onIconSelected,
    Key? key,
  })  : icons = [
          Icons.label,
          Icons.star,
          Icons.wifi,
          Icons.link,
          Icons.home,
          Icons.phone_android,
          Icons.email,
          Icons.credit_card,
          Icons.lock,
          Icons.location_on,
          Icons.person,
          Icons.shopping_cart,
        ],
        iconNames = [
          'label',
          'star',
          'wifi',
          'link',
          'home',
          'phone_android',
          'email',
          'credit_card',
          'lock',
          'location_on',
          'person',
          'shopping_cart',
        ],
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(icons.length, (i) {
        final isSelected = iconNames[i] == selectedIcon;
        return GestureDetector(
          onTap: () => onIconSelected(iconNames[i]),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              icons[i],
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}
