import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class SearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFocus;
  final VoidCallback? onClear;

  const SearchBar({
    super.key,
    this.onChanged,
    this.onFocus,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
      ),
      child: TextField(
        onChanged: onChanged,
        onTap: onFocus,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search "milk, bread, butter"',
          hintStyle: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textMuted),
          suffixIcon: onClear != null
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
