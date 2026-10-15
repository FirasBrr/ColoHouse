import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/ui/widgets/auth_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _bio;
  late TextEditingController _institution;
  late TextEditingController _occupation;

  int? _cityId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user!;
    _firstName = TextEditingController(text: user.firstName);
    _lastName = TextEditingController(text: user.lastName);
    _phone = TextEditingController(text: user.phone);
    _bio = TextEditingController(text: user.bio);
    _institution = TextEditingController(text: user.institution);
    _occupation = TextEditingController(text: user.occupation);
    _cityId = user.city?.id;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _bio.dispose();
    _institution.dispose();
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).updateProfile({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
        'institution': _institution.text.trim(),
        'occupation': _occupation.text.trim(),
        'city_id': _cityId,
      });
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(cityListProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Verification status banner ---
                if (user != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: user.isVerified
                          ? AppColors.secondaryContainer
                              .withValues(alpha: 0.4)
                          : AppColors.tertiaryFixed.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          user.isVerified
                              ? Icons.verified
                              : Icons.info_outline,
                          size: 18,
                          color: user.isVerified
                              ? AppColors.primaryDark
                              : AppColors.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.isVerified
                                ? 'Your account is verified.'
                                : 'Fill in your profile completely. An admin will review and verify your account.',
                            style: TextStyle(
                              fontSize: 12,
                              color: user.isVerified
                                  ? AppColors.primaryDark
                                  : AppColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // --- Avatar placeholder ---
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondaryContainer
                                  .withValues(alpha: 0.4),
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25),
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: user?.profilePicture != null &&
                                      user!.profilePicture!.isNotEmpty
                                  ? Image.network(
                                      user.profilePicture!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person,
                                              size: 48,
                                              color: AppColors.outline),
                                    )
                                  : const Icon(Icons.person,
                                      size: 48, color: AppColors.outline),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(
                                    color: AppColors.surface, width: 2),
                              ),
                              child: const Icon(Icons.photo_camera,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Picture upload coming soon',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: AuthField(
                        controller: _firstName,
                        label: 'First name',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthField(
                        controller: _lastName,
                        label: 'Last name',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _phone,
                  label: 'Phone number',
                  hint: '+216 12 345 678',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell others about yourself…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),

                AuthField(
                  controller: _institution,
                  label: 'Institution / Organization (optional)',
                  hint: 'Company, school, or leave blank',
                  prefixIcon: Icons.school_outlined,
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _occupation,
                  label: 'Occupation / Field (optional)',
                  hint: 'e.g. Engineer, Designer, Student',
                  prefixIcon: Icons.work_outline,
                ),
                const SizedBox(height: 16),

                citiesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                  error: (e, _) => Text(
                    'Failed to load cities: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  data: (cities) => DropdownButtonFormField<int?>(
                    initialValue: _cityId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'City (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...cities.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            c.region.isEmpty
                                ? c.name
                                : '${c.name} — ${c.region}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _cityId = v),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}