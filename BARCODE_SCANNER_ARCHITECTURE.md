# Barcode Scanner - Technical Architecture

## Keyboard Event Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│ BARCODE SCANNER (USB/Bluetooth)                                         │
│ Sends: 8991234567890 + [Enter/Tab] as keyboard characters              │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ CashierPage                                                             │
│  └─ BarcodeListener (ConsumerStatefulWidget)                           │
│      ├─ FocusNode (auto-focused, reclaims focus)                       │
│      └─ KeyboardListener (onKeyEvent callback)                         │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ↓
                        onKeyEvent(KeyEvent)
                               │
                               ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ BarcodeScannerNotifier                                                  │
│  onKeyEvent(KeyEvent) → bool                                            │
│  ├─ Is special key? → ignore                                           │
│  ├─ Extract character → add to buffer                                  │
│  ├─ Is Enter/Tab detected? → return true (barcode complete)            │
│  └─ Otherwise → return false (continue accumulating)                   │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                     ┌─────────┴─────────┐
                     │                   │
             barcode NOT complete    barcode complete
                     │                   │
                     ↓                   ↓
            Continue listening    Call _handleBarcodeComplete()
                                          │
                                          ↓
        ┌─────────────────────────────────────────────────────┐
        │ Read from productsProvider (Riverpod AsyncNotifier) │
        │ Search: product.barcode?.trim() == barcode.trim()  │
        └─────────────────────────────────────────────────────┘
                     │
         ┌───────────┴────────────┐
         │                        │
    Product FOUND            Product NOT FOUND
         │                        │
         ↓                        ↓
  cartProvider.notifier    Show red snackbar:
  .addProduct(product)     "Produk tidak ditemukan"
         │
         ├─ Check if already in cart
         ├─ If exists: increment qty
         ├─ If new: create CartItem
         ├─ Update CartState
         │
         └─→ UI updates (cart refreshes)
             Show green snackbar:
             "Produk ditambahkan ke keranjang"
```

---

## Component Interaction Sequence

```
User Action → Keyboard Event → Listener → Provider → Database → Cart → UI Feedback

Example: Scanning barcode "8991234567890" + Enter

Time  Component              Action                           Result
────  ──────────────────────────────────────────────────────────────────
T0    Scanner              Types '8', '9', '9', '1'...     Characters received
T1    KeyboardListener     Passes each KeyEvent             onKeyEvent called
T2    BarcodeScannerNotif  Accumulates chars                buffer = "8991234567890"
T3    KeyboardListener     Detects Enter key                isComplete = true
T4    BarcodeListener      Reads scanner.buffer             barcode = "8991234567890"
T5    BarcodeListener      Searches productsProvider        Products fetched
T6    BarcodeListener      Finds product by barcode         Found: Semen 25kg
T7    CartNotifier         addProduct() called              Qty incremented/added
T8    CartState            Notifies UI                      Cart refreshes
T9    ScaffoldMessenger    Shows green snackbar             User confirmation
T10   BarcodeScannerNotif  clearBuffer()                    Ready for next scan
```

---

## State Flow Diagram

```
┌──────────────────────────────┐
│ BarcodeScannerState          │
├──────────────────────────────┤
│ buffer: String               │  "8991234567890"
│ isScanning: bool             │  false (unused in current impl)
└──────────────────────────────┘
         │
         │ onKeyEvent(KeyEvent)
         ↓
    Character extracted → buffer appended → state updated
         │
         │ Enter key detected
         ↓
    ┌──────────────────────────────┐
    │ CartState                    │
    ├──────────────────────────────┤
    │ items: List<CartItem>        │  [CartItem(...), CartItem(...)]
    │ discount: double             │  0
    │ taxEnabled: bool             │  false
    │ taxRate: double              │  0.11
    └──────────────────────────────┘
         │
         │ addProduct(product)
         ↓
    If product.id in items:
    ├─ items[i].quantity += 1
    └─ state updated (Riverpod notifies listeners)
    
    OR
    
    If product not in items:
    ├─ Create new CartItem(id, product, unit, qty=1)
    ├─ Add to items list
    └─ state updated (Riverpod notifies listeners)
         │
         ↓
    UI rebuilds (cart panel shows updated list)
```

---

## Import/Dependency Hierarchy

```
cashier_page.dart
├─ barcode_listener.dart
│  ├─ barcode_scanner_provider.dart
│  │  └─ flutter_riverpod (NotifierProvider)
│  │
│  ├─ product_provider.dart
│  │  └─ products list from Firestore
│  │
│  ├─ cart_provider.dart
│  │  └─ CartNotifier.addProduct()
│  │
│  └─ product.dart (model)
│
├─ (existing) payment_dialog.dart
├─ (existing) product grid widget
└─ (existing) cart panel widget
```

---

## Focus Management Flow

```
CashierPage (ConsumerStatefulWidget)
    │
    └─ BarcodeListener (ConsumerStatefulWidget)
       │
       ├─ initState()
       │  └─ Create FocusNode
       │  └─ addPostFrameCallback → _focusNode.requestFocus()
       │
       ├─ KeyboardListener(focusNode: _focusNode, onKeyEvent: ...)
       │  └─ Receives all keyboard events when focused
       │
       ├─ Focus(onFocusChange: ...)
       │  └─ If focus lost → _focusNode.requestFocus()
       │
       └─ child: Row(  // The actual UI
          ├─ Product grid (left)
          └─ Cart panel (right)

Result: KeyboardListener stays focused throughout session
        Unless user explicitly unfocuses the entire page
        Even when clicking search field, category chips, qty buttons, etc.
```

---

## Error Handling & Edge Cases

| Scenario | Handling | Result |
|----------|----------|--------|
| Invalid barcode | Search returns no product | Red snackbar "Produk tidak ditemukan" |
| User presses Enter without barcode | Buffer empty, ignored | No action |
| Backspace key pressed | Filtered as special key | Ignored (no editing) |
| User clicks search field & types | Search field gets focus | Barcode listener still active (doesn't interfere) |
| Product has empty barcode field | Won't match in search | Returns not found |
| Multiple products same barcode | `.firstWhere()` returns first | Would add first match (ideally prevent in DB validation) |
| Scanner sends only numbers | Extracted as characters | Works normally |
| Scanner sends special chars | Extracted as characters | Stored in buffer, searched as-is |
| User switches tabs to Products | Focus lost | RawKeyboardListener inactive (expected) |
| Return to CashierPage | Focus regained | Barcode listener reactivates |

---

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Key event received → buffer append | <1ms | In-memory operation |
| Barcode complete detection | <1ms | Simple key comparison |
| Search products list | 5-50ms | Depends on product count (local search) |
| Cart add/increment | <1ms | In-memory Riverpod update |
| UI rebuild (cart) | 16-33ms | Flutter frame (60 FPS) |
| Snackbar display | Instant | Show/dismiss managed by Flutter |

**Total latency:** ~20-100ms from Enter key press to cart updated (imperceptible to user)

---

## Security & Validation

✓ **No SQL injection risk** - Searching local product list (not DB query string)  
✓ **No code injection** - Character extracted safely from KeyEvent  
✓ **Barcode whitespace tolerant** - `.trim()` prevents false negatives  
✓ **Case sensitive** - Intentional, barcodes are case-sensitive  
✓ **No authentication bypass** - Uses same product lookup as manual search  

---

## Thread Safety

✓ **Riverpod state updates** - Thread-safe (Riverpod handles synchronization)  
✓ **FocusNode operations** - Main thread only (Flutter requirement)  
✓ **KeyboardListener callbacks** - Main thread (Flutter framework)  
✓ **No race conditions** - All barcode events processed sequentially  

---

## Future Enhancement Hooks

If needed, these can be added without major refactoring:

1. **Sound feedback** - Add `AudioPlayer` in `_handleBarcodeComplete()`
2. **Haptic feedback** - Add `HapticFeedback.mediumImpact()` on success
3. **Scan history** - Save barcode scans to Firestore
4. **Duplicate scan prevention** - Timer to ignore repeated barcodes
5. **Inventory sync** - Real-time stock updates during scanning
6. **Barcode validation** - Checksum verification (EAN-13, Code-128, etc.)
7. **Audio alerts** - Play different tones for found/not-found
8. **Barcode whitelist** - Only accept barcodes matching product category

All of these would plug into the existing `_handleBarcodeComplete()` method without affecting core logic.
