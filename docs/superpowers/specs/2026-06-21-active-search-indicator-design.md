# Active Search Indicator — Design Spec

**Date:** 2026-06-21
**Status:** Approved

---

## Problem

When a search query is active, the order list silently filters results with no visible indicator on the main screen. Users can be confused why orders are missing, and there is no way to clear the search without reopening the bottom sheet.

---

## Scope

Add a dismissible search chip that appears in the filter row when `_searchQuery` is non-empty. One-tap clear.

---

## Design

### Placement

Inside `_buildFilters`, below the `_WeekStrip` and above the route chips row. The chip only renders when `_searchQuery.trim().isNotEmpty`.

### Chip Widget

An inline widget — no new file needed. Styled as a `Row` containing:
- A search icon (`Icons.search_rounded`, size 14, `AppColors.primary`)
- Text: `"${_searchQuery.trim()}"` — truncated to 1 line with ellipsis, `maxWidth` constrained so it doesn't push the × off screen
- A clear icon button (`Icons.close_rounded`, size 16, `AppColors.primary`)

Container styling:
- Background: `AppColors.primary.withValues(alpha: 0.08)`
- Border: `AppColors.primary.withValues(alpha: 0.3)`
- Border radius: `BorderRadius.circular(999)`
- Padding: `symmetric(horizontal: 12, vertical: 6)`

Wrapped in `AnimatedSwitcher` (duration 180ms) so it fades in/out smoothly as search becomes active/inactive.

### Clear Action

Tapping the × calls:
```dart
setState(() {
  _searchQuery = '';
  _searchController.clear();
});
```

This mirrors exactly what the "onClear" callback in `_OrdersSearchSheet` does.

### Where It Lives

Added directly in `_buildFilters` in `order_list_screen.dart`. No new file, no new widget class — it's a small inline widget block.

### Files Changed

| File | Change |
|------|--------|
| `lib/features/owner/orders/order_list_screen.dart` | Add animated search chip in `_buildFilters` |

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Query is whitespace only | Chip does not appear (`trim().isNotEmpty` guard) |
| Query is very long | Text truncated with ellipsis at 1 line |
| No orders exist (empty state) | `_buildFilters` is not shown anyway; no change needed |
| Filters sheet clears all (including date) | Search query is NOT cleared by filter sheet clear — separate concerns; user must tap × on chip |

---

## Non-Goals

- No inline search bar on the main screen (stays as bottom sheet).
- No change to the search sheet UI.
- No change to what fields are searched.
