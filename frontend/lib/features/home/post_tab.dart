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
  
  XFile? _selectedImage;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _rent.dispose();
    _deposit.dispose(); _address.dispose(); _rules.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = picked);
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

    setState(() { _loading = true; _error = null; });

    try {
      final repo = ref.read(authRepoProvider);
      
      // 1. Create the listing
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

      // 2. Upload photo if selected (Android uses .path)
      if (_selectedImage != null) {
        await repo.api.uploadListingPhoto(listingId, _selectedImage!.path);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing published successfully!')),
        );
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
      appBar: AppBar(title: const Text('Post a Listing')),
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
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- PHOTO PICKER ---
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
                              SizedBox(height: 8),
                              Text('Tap to upload a photo', style: TextStyle(color: AppColors.primary)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover, width: double.infinity),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                AuthField(controller: _title, label: 'Listing Title', hint: 'e.g. Sunny room in center'),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: AuthField(
                        controller: _rent,
                        label: 'Rent (TND)',
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthField(
                        controller: _deposit,
                        label: 'Deposit (TND)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _roomType,
                  decoration: const InputDecoration(
                    labelText: 'Room Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('Private Room')),
                    DropdownMenuItem(value: 'shared', child: Text('Shared Room')),
                    DropdownMenuItem(value: 'studio', child: Text('Studio')),
                  ],
                  onChanged: (v) => setState(() => _roomType = v!),
                ),
                const SizedBox(height: 16),

                // --- MOVE IN DATE ---
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Available from', border: OutlineInputBorder()),
                    child: Text('${_moveInDate.year}-${_moveInDate.month.toString().padLeft(2, '0')}-${_moveInDate.day.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(height: 16),

                // City Dropdown
                citiesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (cities) => DropdownButtonFormField<int>(
                    initialValue: _cityId,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    items: cities.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (v) => setState(() => _cityId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),

                AuthField(controller: _address, label: 'Exact Address', hint: 'Street name, building...'),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _rules,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'House Rules (Optional)', hintText: 'e.g. No smoking, no pets', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),

                const Text('Pinpoint the exact location:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _point,
                        initialZoom: 13,
                        onTap: (tapPosition, point) {
                          setState(() => _point = point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.colohouse.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _point,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tap on the map to move the pin.', 
                  style: TextStyle(fontSize: 12, color: AppColors.outline)),
                
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publish Listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}