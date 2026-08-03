import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'product_card.dart';

class ProductHorizontalList extends StatelessWidget {
  final List<Product> products;
  final String title;
  final String? subtitle;
  final bool showTimer;
  final VoidCallback? onSeeAll;

  const ProductHorizontalList({
    super.key,
    required this.products,
    required this.title,
    this.subtitle,
    this.showTimer = false,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: title,
          subtitle: subtitle,
          showTimer: showTimer,
          onSeeAllTap: onSeeAll,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: 10,
                  left: index == 0 ? 0 : 0,
                ),
                child: SizedBox(
                  width: 155,
                  child: ProductCard(product: products[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
