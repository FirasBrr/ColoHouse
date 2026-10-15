import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/ui/widgets/auth_field.dart';
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});
  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _maxDistance = TextEditingController();

  String _roomType = '';
  String _sleepSchedule = '';
  double _noiseTolerance = 3;
  double _cleanliness = 3;
  bool _smoker = false;
  bool _acceptsSmokers = true;
  bool _lookingForRoom = false;
  DateTime? _moveInDate;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(authRepoProvider).getPreferences();
      _budget.text = prefs.budget?.toString() ?? '';
      _maxDistance.text = prefs.maxDistanceToCenter?.toString() ?? '';
      _roomType = prefs.preferredRoomType;
      _sleepSchedule = prefs.sleepSchedule;
      _noiseTolerance = (prefs.noiseTolerance ?? 3).toDouble();
      _cleanliness = (prefs.cleanliness ?? 3).toDouble();
      _smoker = prefs.smoker;
      _acceptsSmokers = prefs.acceptsSmokers;
      _lookingForRoom = prefs.lookingForRoom;
      _moveInDate = prefs.moveInDate;
    } catch (_) {
      // leave defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _budget.dispose();
    _maxDistance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).updatePreferences({
        'budget': _budget.text.isEmpty ? null : int.tryParse(_budget.text),
        'preferred_room_type': _roomType,
        'move_in_date':
            _moveInDate?.toIso8601String().substring(0, 10),
        'max_distance_to_center': _maxDistance.text.isEmpty
            ? null
            : double.tryParse(_maxDistance.text),
        'sleep_schedule': _sleepSchedule,
        'noise_tolerance': _noiseTolerance.round(),
        'cleanliness': _cleanliness.round(),
        'smoker': _smoker,
        'accepts_smokers': _acceptsSmokers,
        'looking_for_room': _lookingForRoom,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
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

  Future<void> _pickMoveInDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _moveInDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _noiseLabel(double v) {
    switch (v.round()) {
      case 1: return 'Very quiet';
      case 2: return 'Low noise';
      case 3: return 'Moderate';
      case 4: return 'Lively';
      default: return 'Any sound OK';
    }
  }

  String _cleanLabel(double v) {
    switch (v.round()) {
      case 1: return 'Chilled';
      case 2: return 'Casual';
      case 3: return 'Balanced';
      case 4: return 'Organized';
      default: return 'Immaculate';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Roommate Preferences')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                ],

                // ===== HOUSING =====
                const _SectionTitle('Housing', Icons.home_outlined),
                const SizedBox(height: 12),

                AuthField(
                  controller: _budget,
                  label: 'Budget (per month)',
                  hint: '450',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _roomType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred room type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('No preference')),
                    DropdownMenuItem(
                        value: 'private', child: Text('Private room')),
                    DropdownMenuItem(
                        value: 'shared', child: Text('Shared room')),
                    DropdownMenuItem(value: 'studio', child: Text('Studio')),
                  ],
                  onChanged: (v) => setState(() => _roomType = v ?? ''),
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _maxDistance,
                  label: 'Max distance to city center (km)',
                  hint: '3.5',
                  prefixIcon: Icons.near_me_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Move-in date picker
                InkWell(
                  onTap: _pickMoveInDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      border: Border.all(color: AppColors.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_outlined,
                            size: 20, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _moveInDate == null
                                ? 'Select move-in date'
                                : _formatDate(_moveInDate!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _moveInDate == null
                                  ? AppColors.outline
                                  : AppColors.onSurface,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined,
                            size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                if (_moveInDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _moveInDate = null),
                      child: const Text('Clear date'),
                    ),
                  ),

                const SizedBox(height: 24),

                // ===== LIFESTYLE =====
                const _SectionTitle('Lifestyle', Icons.psychology_outlined),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _sleepSchedule,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sleep schedule',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('No preference')),
                    DropdownMenuItem(
                        value: 'early',
                        child: Text('Early bird (wake before 7 AM)')),
                    DropdownMenuItem(
                        value: 'normal', child: Text('Normal (7 AM – 11 PM)')),
                    DropdownMenuItem(
                        value: 'late', child: Text('Night owl (past midnight)')),
                  ],
                  onChanged: (v) => setState(() => _sleepSchedule = v ?? ''),
                ),
                const SizedBox(height: 20),

                // Noise tolerance slider
                _SliderRow(
                  icon: Icons.volume_up_outlined,
                  label: 'Noise tolerance',
                  value: _noiseTolerance,
                  tag: _noiseLabel(_noiseTolerance),
                  leftLabel: 'Quiet',
                  rightLabel: 'Loud OK',
                  onChanged: (v) => setState(() => _noiseTolerance = v),
                ),
                const SizedBox(height: 16),

                // Cleanliness slider
                _SliderRow(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Cleanliness',
                  value: _cleanliness,
                  tag: _cleanLabel(_cleanliness),
                  leftLabel: 'Relaxed',
                  rightLabel: 'Very tidy',
                  onChanged: (v) => setState(() => _cleanliness = v),
                ),
                const SizedBox(height: 24),

                // ===== PREFERENCES =====
                const _SectionTitle('Preferences', Icons.verified_user_outlined),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('I smoke'),
                        subtitle: const Text(
                          'Includes tobacco and vaping',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _smoker,
                        onChanged: (v) => setState(() => _smoker = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('OK to live with a smoker'),
                        subtitle: const Text(
                          'Open to flatmates who smoke',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _acceptsSmokers,
                        onChanged: (v) =>
                            setState(() => _acceptsSmokers = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Show me as looking for a room'),
                        subtitle: const Text(
                          'Visible to other people searching',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _lookingForRoom,
                        onChanged: (v) =>
                            setState(() => _lookingForRoom = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save preferences'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Discard changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- helpers ----------
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon); 

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String tag;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tag,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('$label: ${value.round()}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(tag,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppColors.primary,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.outline)),
              Text(rightLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.outline)),
            ],
          ),
        ),
      ],
    );
  }
}