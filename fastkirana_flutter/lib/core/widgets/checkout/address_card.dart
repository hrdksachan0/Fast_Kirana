import 'package:flutter/material.dart';

class AddressCard extends StatelessWidget {
  final String label;
  final String fullAddress;
  final bool isSelected;
  final VoidCallback onTap;
  const AddressCard({
    super.key,
    required this.label,
    required this.fullAddress,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignSystem.primaryBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppDesignSystem.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600,
                      color: isSelected ? AppDesignSystem.primary : AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(fullAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
