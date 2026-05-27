// lib/shared/widgets/app_data_table.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppDataTableColumn {
  final String label;
  final int flex;
  final TextAlign align;

  const AppDataTableColumn({
    required this.label,
    this.flex = 1,
    this.align = TextAlign.left,
  });
}

class AppDataTable<T> extends StatelessWidget {
  final List<AppDataTableColumn> columns;
  final List<T> rows;
  final Widget Function(BuildContext context, T item, int index) rowBuilder;
  final String emptyMessage;
  final IconData emptyIcon;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.rowBuilder,
    this.emptyMessage = 'Tidak ada data',
    this.emptyIcon = Icons.table_rows_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, color: AppColors.textDisabled, size: 48),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: columns.map((col) => Expanded(
              flex: col.flex,
              child: Text(
                col.label,
                textAlign: col.align,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )).toList(),
          ),
        ),

        // Data rows
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) =>
                rowBuilder(context, rows[index], index),
          ),
        ),
      ],
    );
  }
}
