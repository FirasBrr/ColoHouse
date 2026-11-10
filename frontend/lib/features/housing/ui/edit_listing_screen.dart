import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/auth_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/ui/widgets/auth_field.dart';
import '../models/listing.dart';

class EditListingScreen extends ConsumerStatefulWidget {
  final HousingListing listing;
  const EditListingScreen({super.key, required this.listing});

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _rent;
  late TextEditingController _deposit;
  late TextEditingController _address;
  late TextEditingController _rules;
  
  late bool _isActive;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.listing.title);
    _desc = TextEditingController(text: widget.listing.description);
    _rent = TextEditingController(text: widget.listing.rent.toString());
    _deposit = TextEditingController(text: widget.listing.deposit.toString());
    _address = TextEditingController(text: widget.listing.address ?? '');
    _rules = TextEditingController(text: widget.listing.rules);
    _isActive = widget.listing.status == 'active';
  }

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _rent.dispose();
    _deposit.dispose(); _address.dispose(); _rules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(authRepoProvider).api.updateListing(widget.listing.id, {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'rent': int.parse(_rent.text),
        'deposit': _deposit.text.isEmpty ? 0 : int.parse(_deposit.text),
        'address': _address.text.trim(),
        'rules': _rules.text.trim(),
        'status': _isActive ? 'active' : 'paused',
      });

      ref.invalidate(listingsProvider('')); 
      ref.invalidate(listingDetailsProvider(widget.listing.id));
      ref.invalidate(myListingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated!')),
        );
        context.pop();
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Edit Listing')),
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

                // Status Toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: SwitchListTile(
                    title: const Text('Listing is Active'),
                    subtitle: const Text('Turn off to pause and hide from search'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                const SizedBox(height: 20),

                AuthField(controller: _title, label: 'Listing Title'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: AuthField(controller: _rent, label: 'Rent (TND)', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: AuthField(controller: _deposit, label: 'Deposit (TND)', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                AuthField(controller: _address, label: 'Exact Address'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rules,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'House Rules', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}