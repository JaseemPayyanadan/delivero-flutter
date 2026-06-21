# Active Search Indicator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a dismissible animated chip in the filter row whenever a search query is active, with one-tap clear.

**Architecture:** Inline widget block added to `_buildFilters` in `order_list_screen.dart` — no new files, no new widget class. Wrapped in `AnimatedSwitcher` for smooth fade.

**Tech Stack:** Flutter, Dart.

## Global Constraints

- No new widget class or file — inline only, inside `_buildFilters`
- Chip appears only when `_searchQuery.trim().isNotEmpty`
- Background: `AppColors.primary.withValues(alpha: 0.08)`
- Border: `AppColors.primary.withValues(alpha: 0.3)`, `BorderRadius.circular(999)`
- Padding: `symmetric(horizontal: 12, vertical: 6)`
- Animation: `AnimatedSwitcher`, duration 180ms
- Clear action: `setState(() { _searchQuery = ''; _searchController.clear(); })`

---

### Task 1: Add animated search chip to `_buildFilters`

**Files:**
- Modify: `lib/features/owner/orders/order_list_screen.dart` (at `_buildFilters`, lines 331-387)

**Interfaces:**
- Consumes: `_searchQuery` (String field on `_OrderListScreenState`), `_searchController` (TextEditingController), `AppColors.primary`

- [ ] **Step 1: Locate the insertion point in `_buildFilters`**

The `_buildFilters` method returns a `Column`. Its children are:
1. `_WeekStrip(...)` at line ~338
2. Optional `SizedBox` + route chips row at line ~358

Insert the new chip row BETWEEN the `_WeekStrip` and the route chips `if` block, so the Column's children order becomes:
1. `_WeekStrip(...)`
2. `AnimatedSwitcher(...)` — the new search chip (always present in widget tree; child is null when inactive)
3. Optional route chips row

- [ ] **Step 2: Write the chip widget inline**

In `_buildFilters`, after the `_WeekStrip(...)` child and before the route-chips `if` block, add:

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 180),
  child: _searchQuery.trim().isNotEmpty
      ? Padding(
          key: const ValueKey('search-chip'),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 32,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _searchQuery.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      : const SizedBox.shrink(),
),
```

- [ ] **Step 3: Hot-restart the app and test manually**

1. Open the app to the Orders screen.
2. Tap the search icon → enter a query (e.g. "Ahmed").
3. Confirm: chip appears below the week strip with the query text, a search icon, and a × button.
4. Tap × → chip disappears, orders un-filter.
5. Enter a whitespace-only query → chip must NOT appear.
6. Enter a very long query (30+ chars) → text should truncate with ellipsis.

- [ ] **Step 4: Run the full test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass (count ≥ 76).

- [ ] **Step 5: Commit**

```bash
git add lib/features/owner/orders/order_list_screen.dart
git commit -m "feat: add animated search indicator chip to order filter row

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Self-Review

- ✅ Spec: chip only appears when `_searchQuery.trim().isNotEmpty`
- ✅ Spec: `AnimatedSwitcher` with 180ms duration used
- ✅ Spec: background `AppColors.primary.withValues(alpha: 0.08)`, border `alpha: 0.3`, radius 999
- ✅ Spec: padding `symmetric(horizontal: 12, vertical: 6)`
- ✅ Spec: clear calls `setState { _searchQuery = ''; _searchController.clear(); }`
- ✅ Spec: no new file or widget class
- ✅ Long query truncates with ellipsis (Flexible + maxLines: 1)
- ✅ `ValueKey` on active child so AnimatedSwitcher animates correctly
