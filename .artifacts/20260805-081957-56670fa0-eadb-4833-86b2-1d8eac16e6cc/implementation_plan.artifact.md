# Implementation Plan - Fix Numeric Parsing and Decimal Precision

This plan addresses the inconsistency between dot/comma separators in different pages and fixes the rounding bug in product conversions.

## Proposed Changes

### Core Utilities

#### [formatters.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/core/utils/formatters.dart)
- Update `_decimal` to support up to 5 decimal places (`#,##0.#####`).
- Rename/Add `parsePrice`: Strictly treats `.` as thousand and `,` as decimal.
- Add `parseQuantity`: Treats **both** `.` and `,` as decimal points (ignores thousand separators). This resolves the ambiguity for QTY fields.

### Product Management

#### [product_form_dialog.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/features/products/presentation/widgets/product_form_dialog.dart)
- Update all validators for Price fields to use `Formatters.parsePrice`.
- Update validators for QTY and Conversion fields to use `Formatters.parseQuantity`.
- Update `_UnitEntry` methods to display and parse up to 5 decimal places.

#### [products_page.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/features/products/presentation/pages/products_page.dart)
- Update Instant QTY update logic to use `Formatters.parseQuantity` instead of `double.tryParse`.

### Inventory

#### [restock_dialog.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/features/inventory/presentation/widgets/restock_dialog.dart)
- Update validators and calculations to use the new parsing logic (Price vs Quantity).

### Cashier

#### [cart_panel.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/features/cashier/presentation/widgets/cart_panel.dart)
- Update QTY and Discount field parsers to use `Formatters.parseQuantity` (allowing `,`).
- Update the display logic to prevent forced rounding of small quantities.

### Shared Widgets

#### [common_widgets.dart](file:///D:/Code/construction_pos/Construction Store Pos/lib/shared/widgets/common_widgets.dart)
- Update `ScrollableQtyField` to use 5 decimal places for formatting.
- Sync its internal `_parseValue` with `Formatters.parseQuantity`.

## Verification Plan

### Manual Verification
1.  **Product Dialog**:
    - Input `1,5` in Stok -> Ensure it calculates Modal correctly and saves successfully.
    - Input `0.002` in Konversi -> Ensure it stays `0.002` and doesn't round to `0.00`.
2.  **Cashier Page**:
    - Add item -> Input `1,5` in QTY field -> Ensure it updates the total correctly.
    - Input `1.5` in QTY field -> Ensure it also works correctly.
3.  **Instant QTY**:
    - Type `1,5` or `1.5` in the "±Qty" box in the product list -> Ensure it updates stock by 1.5.
4.  **Price Fields**:
    - Type `1.500` in "Harga Modal" -> Ensure it reads as 1500.
    - Type `1.500,50` -> Ensure it reads as 1500.5.
