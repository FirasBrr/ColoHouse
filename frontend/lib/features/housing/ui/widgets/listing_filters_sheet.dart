import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/listing_filters.dart';

// Opens the search filters. Returns the new filters, or null if the sheet was dismissed.
Future<ListingFilters?> showListingFiltersSheet(BuildContext context, ListingFilters current) {
  return showModalBottomSheet<ListingFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true, // Cover the bottom navigation bar
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ListingFiltersSheet(initial: current),
  );
}

class ListingFiltersSheet extends ConsumerStatefulWidget {
  final ListingFilters initial;

  const ListingFiltersSheet({super.key, required this.initial});

  @override
  ConsumerState<ListingFiltersSheet> createState() => _ListingFiltersSheetState();
}

class _ListingFiltersSheetState extends ConsumerState<ListingFiltersSheet> {
  static const _maxRadiusKm = 50.0;

  static const _roomTypeLabels = {
    null: 'Any',
    'private': 'Private',
    'shared': 'Shared',
    'studio': 'Studio',
  };

  static const _sortLabels = {
    'newest': 'Newest first',
    'rent': 'Price: low to high',
    '-rent': 'Price: high to low',
    'distance': 'Distance from city center',
  };

  int? _cityId;
  String? _roomType;
  late final TextEditingController _minRent;
  late final TextEditingController _maxRent;
  DateTime? _availableBy;
  double? _radiusKm;
  String _ordering = 'newest';
  String? _rentError;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _cityId = f.cityId;
    _roomType = f.roomType;
    _minRent = TextEditingController(text: f.minRent?.toString() ?? '');
    _maxRent = TextEditingController(text: f.maxRent?.toString() ?? '');
    _availableBy = f.availableBy;
    _radiusKm = f.radiusKm?.clamp(1, _maxRadiusKm).toDouble();
    _ordering = f.ordering == 'distance' && f.cityId == null ? 'newest' : f.ordering;
  }

  @override
  void dispose() {
    _minRent.dispose();
    _maxRent.dispose();
    super.dispose();
  }

  void _setCity(int? id) {
    setState(() {
      _cityId = id;
      // Distance filters use the city center, so they go away with the city
      if (id == null) {
        _radiusKm = null;
        if (_ordering == 'distance') _ordering = 'newest';
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _availableBy;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _availableBy = picked);
  }

  void _reset() {
    setState(() {
      _cityId = null;
      _roomType = null;
      _minRent.clear();
      _maxRent.clear();
      _availableBy = null;
      _radiusKm = null;
      _ordering = 'newest';
      _rentError = null;
    });
  }

  void _apply() {
    final minRent = int.tryParse(_minRent.text.trim());
    final maxRent = int.tryParse(_maxRent.text.trim());
    if (minRent != null && maxRent != null && minRent > maxRent) {
      setState(() => _rentError = 'Min rent must be lower than max rent');
      return;
    }
    Navigator.of(context).pop(widget.initial.copyWith(
      cityId: _cityId,
      roomType: _roomType,
      minRent: minRent,
      maxRent: maxRent,
      availableBy: _availableBy,
      radiusKm: _cityId == null ? null : _radiusKm,
      ordering: _ordering,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(cityListProvider);
    final hasCity = _cityId != null;
    final media = MediaQuery.of(context);

    return Padding(
      // Stay above the keyboard while typing a price
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + header
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== CITY =====
                    const _SectionLabel('City'),
                    citiesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Could not load cities: $e', style: const TextStyle(color: AppColors.error)),
                      data: (cities) => DropdownButtonFormField<int?>(
                        key: ValueKey('city-$_cityId'), // Rebuild after Reset
                        initialValue: cities.any((c) => c.id == _cityId) ? _cityId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city, size: 20)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Any city')),
                          ...cities.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: _setCity,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== ROOM TYPE =====
                    const _SectionLabel('Room type'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roomTypeLabels.entries.map((e) {
                        final selected = _roomType == e.key;
                        return ChoiceChip(
                          label: Text(e.value),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _roomType = e.key),
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceLow,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ===== PRICE =====
                    const _SectionLabel('Monthly rent (TND)'),
                    Row(
                      children: [
                        Expanded(child: _rentField(_minRent, 'Min')),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('-', style: TextStyle(color: AppColors.outline, fontSize: 18)),
                        ),
                        Expanded(child: _rentField(_maxRent, 'Max')),
                      ],
                    ),
                    if (_rentError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(_rentError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 20),

                    // ===== AVAILABILITY =====
                    const _SectionLabel('Available by'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          suffixIcon: _availableBy == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _availableBy = null),
                                ),
                        ),
                        child: Text(
                          _availableBy == null ? 'Any date' : ListingFilters.formatDate(_availableBy!),
                          style: TextStyle(fontSize: 16, color: _availableBy == null ? AppColors.outline : AppColors.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===== DISTANCE =====
                    const _SectionLabel('Distance'),
                    Row(
                      children: [
                        Icon(Icons.radar, size: 18, color: hasCity ? AppColors.primary : AppColors.outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            !hasCity
                                ? 'Choose a city to search by distance'
                                : _radiusKm == null
                                    ? 'Any distance'
                                    : 'Within ${_radiusKm!.round()} km of the city center',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: hasCity ? AppColors.onSurface : AppColors.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusKm ?? 0,
                      min: 0,
                      max: _maxRadiusKm,
                      divisions: _maxRadiusKm.toInt(),
                      activeColor: AppColors.primary,
                      label: _radiusKm == null ? 'Any' : '${_radiusKm!.round()} km',
                      onChanged: hasCity ? (v) => setState(() => _radiusKm = v == 0 ? null : v) : null,
                    ),
                    const SizedBox(height: 12),

                    // ===== SORT =====
                    const _SectionLabel('Sort by'),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sort-$_ordering-$hasCity'), // Rebuild when Distance appears / disappears
                      initialValue: _ordering,
                      isExpanded: true,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.sort, size: 20)),
                      items: [
                        for (final o in ListingFilters.orderings)
                          if (o != 'distance' || hasCity) DropdownMenuItem(value: o, child: Text(_sortLabels[o]!)),
                      ],
                      onChanged: (v) => setState(() => _ordering = v ?? 'newest'),
                    ),
                  ],
                ),
              ),
            ),

            // ===== ACTIONS =====
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _apply,
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rentField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      onChanged: (_) {
        if (_rentError != null) setState(() => _rentError = null);
      },
      decoration: InputDecoration(labelText: label, hintText: label == 'Min' ? '0' : 'No limit'),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
    );
  }
}
