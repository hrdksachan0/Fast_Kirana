import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';
import 'search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final List<String> _recent = ['Milk', 'Bread', 'Eggs', 'Tomato'];
  final List<String> _trending = ['Amul Milk', 'Onion', 'Rice 5kg', 'Maggi', 'Coca Cola', 'Lays'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.borderLight),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Search groceries...',
                          hintStyle: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textMuted),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => SearchResultsScreen(query: value),
                            ));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.tune_rounded, color: AppDesignSystem.primary),
                    style: IconButton.styleFrom(backgroundColor: AppDesignSystem.primary.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_recent.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Searches', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                        TextButton(onPressed: () => setState(() => _recent.clear()), child: Text('Clear', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.danger))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recent.map((r) => GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchResultsScreen(query: r))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppDesignSystem.borderLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 14, color: AppDesignSystem.textSecondary),
                              const SizedBox(width: 4),
                              Text(r, style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textPrimary)),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trending Now', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                      Icon(Icons.trending_up_rounded, color: AppDesignSystem.primary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._trending.map((t) => GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchResultsScreen(query: t))),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesignSystem.borderLight),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.textSecondary),
                          const SizedBox(width: 12),
                          Text(t, style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textPrimary)),
                        ],
                      ),
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}