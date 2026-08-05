# Walkthrough - Numeric Parsing & Decimal Precision Fix

I have resolved the inconsistency between dot and comma separators and fixed the rounding issues in product conversions.

## Changes Made

### 1. Robust Parsing Logic
- **Quantity Parsing:** Updated to treat both `.` and `,` as decimal points. This allows users to type `1,5` or `1.5` interchangeably for quantities without errors.
- **Price Parsing:** Retained strict Indonesian format (`.` for thousands, `,` for decimal) to ensure financial accuracy.
- **Form Validation:** Synchronized validators with the new parsing logic so the "Simpan" button no longer blocks valid inputs using commas.

### 2. High-Precision Decimals
- **Increased Precision:** Expanded support to **5 decimal places** for all quantity-related fields.
- **Rounding Fix:** Prevented the UI from rounding small values like `0.002` to `0.00`. These values are now displayed and calculated at their full precision.

### 3. Unified UI Behavior
- **Cashier & Product Pages:** Updated all QTY and Discount fields to use the same logic, ensuring a consistent experience whether adding a new product or selling at the register.
- **Scrollable Fields:** Updated the `ScrollableQtyField` to handle high-precision scrolling and display correctly.

## Verification Summary

### Manual Tests Passed
- [x] **Product Form:** `1,5` in Stok calculates correctly and saves.
- [x] **Product Form:** `0.002` in Konversi stays `0.002` (no rounding).
- [x] **Cashier:** `1,5` in QTY field updates total correctly.
- [x] **Price Fields:** `1.500` is parsed as 1500 (thousands marking works).
- [x] **Instant QTY:** `1,5` in the product list updates stock correctly.

All numeric fields now behave predictably based on their context (Money vs. Measurement).
