import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../providers/voter_provider.dart';
import 'voter_registration_result_screen.dart';

/// Admin "Create Voter" page.
///
/// Collects all voter details, validates every field, and on submission
/// calls `POST /voter/create`. The backend then:
///  1. Re-validates the payload (server-side authority).
///  2. Opens the server webcam (OpenCV), runs single-face detection, centering,
///     stability, and a 3-2-1 countdown, then auto-captures.
///  3. Rejects blur / low brightness / overexposure / low resolution /
///     too-small / partial frame / multiple faces.
///  4. Saves the image as `<NID>.jpg`, generates the ArcFace embedding, and
///     inserts the record.
///
/// While the backend is capturing, this screen shows a "camera active" state.
/// If the backend returns a 409 `duplicate_image`, the admin is prompted to
/// replace the existing face image before retrying.
class CreateVoterScreen extends StatefulWidget {
  const CreateVoterScreen({super.key});

  @override
  State<CreateVoterScreen> createState() => _CreateVoterScreenState();
}

class _CreateVoterScreenState extends State<CreateVoterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _cameraActive = false;

  final _nid = TextEditingController();
  final _fullName = TextEditingController();
  final _fatherName = TextEditingController();
  final _motherName = TextEditingController();
  final _dob = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _permanentAddress = TextEditingController();
  final _presentAddress = TextEditingController();
  final _areaCode = TextEditingController();
  final _constituency = TextEditingController();

  String _gender = 'Male';
  bool _registrationStatus = true;
  bool _eligibilityStatus = true;
  String _accountStatus = 'Active';

  @override
  void dispose() {
    _nid.dispose();
    _fullName.dispose();
    _fatherName.dispose();
    _motherName.dispose();
    _dob.dispose();
    _mobile.dispose();
    _email.dispose();
    _permanentAddress.dispose();
    _presentAddress.dispose();
    _areaCode.dispose();
    _constituency.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dob.text) ?? now.subtract(const Duration(days: 30 * 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      _dob.text = '$y-$m-$d';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _cameraActive = true;
    });

    final provider = context.read<VoterProvider>();
    try {
      final result = await provider.createVoter(
        nid: _nid.text.trim(),
        fullName: _fullName.text.trim(),
        fatherName: _emptyToNull(_fatherName.text),
        motherName: _emptyToNull(_motherName.text),
        dob: _dob.text.trim(),
        gender: _gender,
        mobile: _emptyToNull(_mobile.text),
        email: _emptyToNull(_email.text),
        permanentAddress: _emptyToNull(_permanentAddress.text),
        presentAddress: _emptyToNull(_presentAddress.text),
        areaCode: _emptyToNull(_areaCode.text),
        constituency: _emptyToNull(_constituency.text),
        registrationStatus: _registrationStatus,
        eligibilityStatus: _eligibilityStatus,
        accountStatus: _accountStatus,
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoterRegistrationResultScreen(result: result),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      final data = e.data;
      final isDuplicateImage =
          data is Map<String, dynamic> && data['duplicate_image'] == true;
      if (isDuplicateImage) {
        await _promptReplaceImage(provider);
      } else {
        final validation = data is Map<String, dynamic> ? data['validation'] : null;
        _showError(validation is Map<String, dynamic>
            ? _validationSummary(validation)
            : e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      _showError(ApiClient.friendlyMessage(e));
    }
  }

  Future<void> _promptReplaceImage(VoterProvider provider) async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: const Text('Replace existing face image?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'A registered face image already exists for NID ${_nid.text.trim()}. '
          'Re-run the camera capture to replace it?',
          style: const TextStyle(color: Palette.inkMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.navy,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;

    setState(() {
      _submitting = true;
      _cameraActive = true;
    });
    try {
      final result = await provider.createVoter(
        nid: _nid.text.trim(),
        fullName: _fullName.text.trim(),
        fatherName: _emptyToNull(_fatherName.text),
        motherName: _emptyToNull(_motherName.text),
        dob: _dob.text.trim(),
        gender: _gender,
        mobile: _emptyToNull(_mobile.text),
        email: _emptyToNull(_email.text),
        permanentAddress: _emptyToNull(_permanentAddress.text),
        presentAddress: _emptyToNull(_presentAddress.text),
        areaCode: _emptyToNull(_areaCode.text),
        constituency: _emptyToNull(_constituency.text),
        registrationStatus: _registrationStatus,
        eligibilityStatus: _eligibilityStatus,
        accountStatus: _accountStatus,
        replaceExistingImage: true,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoterRegistrationResultScreen(result: result),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _cameraActive = false;
      });
      _showError(ApiClient.friendlyMessage(e));
    }
  }

  String _validationSummary(Map<String, dynamic> validation) {
    final messages = validation.values
        .whereType<String>()
        .map((s) => '• $s');
    return messages.join('\n');
  }

  String? _emptyToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Palette.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 19) : null,
      filled: true,
      fillColor: const Color(0xFFF6F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.error, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.paper,
      appBar: AppBar(
        title: const Text('Create Voter'),
        backgroundColor: Palette.navyDeep,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(),
                const SizedBox(height: 16),
                _buildButtons(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_cameraActive) _buildCameraOverlay(),
        ],
      ),
    );
  }

  Widget _sectionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Palette.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.badge_outlined, 'Identity & Contact'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nid,
            keyboardType: TextInputType.number,
            decoration: _decoration('National ID (NID) *', icon: Icons.badge_outlined),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'NID is required';
              if (!RegExp(r'^\d+$').hasMatch(t)) return 'NID must contain digits only';
              if (t.length > 20) return 'NID must be at most 20 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _fullName,
            decoration: _decoration('Full Name *', icon: Icons.person_outline),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Full name is required';
              if (t.length > 100) return 'Full name must be at most 100 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fatherName,
                  decoration: _decoration("Father's Name", icon: Icons.man_outlined),
                  validator: (v) =>
                      (v ?? '').trim().length > 100 ? 'At most 100 characters' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _motherName,
                  decoration: _decoration("Mother's Name", icon: Icons.woman_outlined),
                  validator: (v) =>
                      (v ?? '').trim().length > 100 ? 'At most 100 characters' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dob,
                  readOnly: true,
                  onTap: _pickDob,
                  decoration: _decoration('Date of Birth *', icon: Icons.calendar_today_outlined),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Date of birth is required';
                    final parsed = DateTime.tryParse(t);
                    if (parsed == null) return 'Use YYYY-MM-DD';
                    if (!parsed.isBefore(DateTime.now())) return 'Must be in the past';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: _decoration('Gender', icon: Icons.wc_outlined),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _gender = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration('Mobile Number', icon: Icons.phone_outlined),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (!RegExp(r'^(?:\+?88)?01[3-9]\d{8}$').hasMatch(t)) {
                      return 'Enter a valid Bangladeshi mobile number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Email', icon: Icons.email_outlined),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (t.length > 100 ||
                        !RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
                            .hasMatch(t)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _permanentAddress,
            maxLines: 2,
            decoration: _decoration('Permanent Address', icon: Icons.home_outlined),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _presentAddress,
            maxLines: 2,
            decoration: _decoration('Present Address', icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _areaCode,
                  decoration: _decoration('Area Code', icon: Icons.map_outlined),
                  validator: (v) =>
                      (v ?? '').trim().length > 10 ? 'At most 10 characters' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _constituency,
                  decoration: _decoration('Constituency', icon: Icons.location_city_outlined),
                  validator: (v) =>
                      (v ?? '').trim().length > 50 ? 'At most 50 characters' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Palette.hairline),
          const SizedBox(height: 8),
          _sectionTitle(Icons.tune_rounded, 'Status'),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Registration Status'),
            subtitle: const Text('Mark the voter as registered'),
            value: _registrationStatus,
            activeTrackColor: Palette.success,
            onChanged: (v) => setState(() => _registrationStatus = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Eligibility Status'),
            subtitle: const Text('Voter is eligible to vote'),
            value: _eligibilityStatus,
            activeTrackColor: Palette.success,
            onChanged: (v) => setState(() => _eligibilityStatus = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _accountStatus,
            decoration: _decoration('Account Status', icon: Icons.verified_user_outlined),
            items: const [
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _accountStatus = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Palette.navy),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Palette.navy,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Register & Capture Face'),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Palette.gold),
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Camera active',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'The server webcam is capturing the voter\'s face.\n'
                  'Position the face inside the guide, stay still, and wait\n'
                  'for the 3…2…1 countdown. This may take a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.inkMuted, fontSize: 13, height: 1.4),
                ),
                SizedBox(height: 14),
                Text(
                  'Do not close this window until the capture completes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.warning, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
