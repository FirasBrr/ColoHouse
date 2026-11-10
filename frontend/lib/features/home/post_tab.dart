import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/errors/auth_exception.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/ui/widgets/auth_field.dart';

class PostTab extends ConsumerStatefulWidget {
  const PostTab({super.key});

  @override
  ConsumerState<PostTab> createState() => _PostTabState();
}

class _PostTabState extends ConsumerState<PostTab> {
  final _formKey = GlobalKey<FormState>();
  
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _address = TextEditingController();
  final _rules = TextEditingController();
  
  String _roomType = 'private';
  int? _cityId;
  DateTime _moveInDate = DateTime.now().add(const Duration(days: 7));
  LatLng _point = const LatLng(36.8065, 10.1815);
  
  final List<XFile> _selectedImages = []; 
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _rent.dispose();
    _deposit.dispose(); _address.dispose(); _rules.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 70);
    
    if (pickedList.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedList);
        if (_selectedImages.length > 5) {
          _selectedImages.removeRange(5, _selectedImages.length); // Max 5 photos
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _moveInDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityId == null) {
      setState(() => _error = 'Please select a city');
      return;
    }
    if (_selectedImages.isEmpty) {
      setState(() => _error = 'Please add at least one photo');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final repo = ref.read(authRepoProvider);
      
      final listingId = await repo.api.createListing(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        rent: int.parse(_rent.text),
        deposit: _deposit.text.isEmpty ? 0 : int.parse(_deposit.text),
        roomType: _roomType,
        cityId: _cityId!,
        address: _address.text.trim(),
        latitude: _point.latitude,
        longitude: _point.longitude,
        availableFrom: _moveInDate.toIso8601String().substring(0, 10),
        rules: _rules.text.trim(),
      );

      // Upload images in order (first image will be the cover)
      final paths = _selectedImages.map((e) => e.path).toList();
      await repo.api.uploadMultiplePhotos(listingId, paths);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing published successfully!')),
        );
        _title.clear(); _desc.clear(); _rent.clear(); _deposit.clear();
        _address.clear(); _rules.clear();
        setState(() => _selectedImages.clear());
        
        ref.invalidate(listingsProvider('')); 
        context.go('/search'); 
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(cityListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Post a Listing'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                ],

                // ===== PHOTOS SECTION =====
                const Text('Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('First photo will be the cover', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                const SizedBox(height: 12),
                
                // CENTERED PHOTO PICKER
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 1. Render Selected Images
                        ...List.generate(_selectedImages.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_selectedImages[index].path),
                                    width: 110, 
                                    height: 110, 
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (index == 0)
                                  Positioned(
                                    bottom: 4, left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedImages.removeAt(index)),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        }),
                        
                        // 2. Render the Add Button at the end
                        if (_selectedImages.length < 5)
                          InkWell(
                            onTap: _pickImages,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                                  SizedBox(height: 8),
                                  Text('Add Photo', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== DETAILS SECTION =====
                _SectionCard(
                  title: 'Listing Details',
                  children: [
                    AuthField(controller: _title, label: 'Title', hint: 'e.g. Sunny private room'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: AuthField(controller: _rent, label: 'Rent (TND)', keyboardType: TextInputType.number, validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: AuthField(controller: _deposit, label: 'Deposit (TND)', keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _roomType,
                      decoration: const InputDecoration(labelText: 'Room Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'private', child: Text('Private Room')),
                        DropdownMenuItem(value: 'shared', child: Text('Shared Room')),
                        DropdownMenuItem(value: 'studio', child: Text('Studio')),
                      ],
                      onChanged: (v) => setState(() => _roomType = v!),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Available from', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today, size: 20)),
                        child: Text('${_moveInDate.year}-${_moveInDate.month.toString().padLeft(2, '0')}-${_moveInDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ===== LOCATION SECTION =====
                _SectionCard(
                  title: 'Location',
                  children: [
                    citiesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (cities) => DropdownButtonFormField<int>(
                        initialValue: _cityId,
                        decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                        items: cities.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _cityId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AuthField(controller: _address, label: 'Exact Address', hint: 'Street name, building...'),
                    const SizedBox(height: 12),
                    const Text('Pinpoint the exact location:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineVariant)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _point,
                            initialZoom: 13,
                            onTap: (_, p) => setState(() => _point = p),
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.colohouse.app'),
                            MarkerLayer(markers: [Marker(point: _point, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ===== RULES SECTION =====
                _SectionCard(
                  title: 'House Rules',
                  children: [
                    TextFormField(
                      controller: _rules,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'e.g. No smoking, no pets, quiet after 10 PM...', border: OutlineInputBorder()),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Publish Listing', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A reusable widget to group form fields into a clean card
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}