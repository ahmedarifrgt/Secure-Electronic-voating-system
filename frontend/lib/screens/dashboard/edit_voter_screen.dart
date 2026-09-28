import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../models/voter.dart';
import '../../providers/voter_provider.dart';

class EditVoterScreen extends StatefulWidget {
  const EditVoterScreen({super.key, required this.voter});

  final Voter voter;

  @override
  State<EditVoterScreen> createState() => _EditVoterScreenState();
}

class _EditVoterScreenState extends State<EditVoterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  late final TextEditingController _nid;
  late final TextEditingController _fullName;
  late final TextEditingController _fatherName;
  late final TextEditingController _motherName;
  late final TextEditingController _dob;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _permanentAddress;
  late final TextEditingController _presentAddress;
  late final TextEditingController _areaCode;
  late final TextEditingController _constituency;

  late String _gender;
  late bool _registrationStatus;
  late bool _eligibilityStatus;
  late String _accountStatus;

  @override
  void initState() {
    super.initState();
    _nid = TextEditingController(text: widget.voter.nid ?? '');
    _fullName = TextEditingController(text: widget.voter.fullName ?? '');
    _fatherName = TextEditingController(text: widget.voter.fatherName ?? '');
    _motherName = TextEditingController(text: widget.voter.motherName ?? '');
    _dob = TextEditingController(text: widget.voter.dob ?? '');
    _mobile = TextEditingController(text: widget.voter.mobile ?? '');
    _email = TextEditingController(text: widget.voter.email ?? '');
    _permanentAddress = TextEditingController(text: widget.voter.permanentAddress ?? '');
    _presentAddress = TextEditingController(text: widget.voter.presentAddress ?? '');
    _areaCode = TextEditingController(text: widget.voter.areaCode ?? '');
    _constituency = TextEditingController(text: widget.voter.constituency ?? '');
    _gender = _normalizeGender(widget.voter.gender);
    _registrationStatus = widget.voter.registrationStatus;
    _eligibilityStatus = widget.voter.eligibilityStatus;
    _accountStatus = widget.voter.accountStatus ?? 'Active';
  }

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

  String _normalizeGender(String? value) {
    const allowed = {'Male', 'Female', 'Other'};
    if (value != null && allowed.contains(value)) {
      return value;
    }
    return 'Male';
  }

  InputDecoration _decoration(String label, {IconData? icon, String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

    if (widget.voter.voterId == null) {
      _showError('This voter record cannot be updated because the voter ID is missing.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    final provider = context.read<VoterProvider>();
    try {
      final updated = await provider.updateVoter(
        voterId: widget.voter.voterId!,
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
      });
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      final validation = e.data is Map<String, dynamic> ? e.data['validation'] : null;
      _showError(validation is Map<String, dynamic> ? _validationSummary(validation) : e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      _showError(ApiClient.friendlyMessage(e));
    }
  }

  String _validationSummary(Map<String, dynamic> validation) {
    return validation.values.whereType<String>().map((value) => '- $value').join('\n');
  }

  void _showError(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.paper,
      appBar: AppBar(
        title: const Text('Edit Voter'),
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
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: Palette.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update voter profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Edit personal details, contact information, and account status.',
                        style: TextStyle(color: Palette.inkMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nid,
                        decoration: _decoration(
                          'National ID (NID) *',
                          icon: Icons.badge_outlined,
                          helperText: 'Changing NID will move the registered face image file.',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final t = value?.trim() ?? '';
                          if (t.isEmpty) return 'NID is required';
                          if (!RegExp(r'^\d{1,20}$').hasMatch(t)) return 'NID must contain digits only';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fullName,
                        decoration: _decoration('Full Name *', icon: Icons.person_outline),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fatherName,
                        decoration: _decoration('Father Name', icon: Icons.family_restroom_outlined),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _motherName,
                        decoration: _decoration('Mother Name', icon: Icons.family_restroom_outlined),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dob,
                        decoration: _decoration('Date of Birth *', icon: Icons.cake_outlined),
                        readOnly: true,
                        onTap: _pickDob,
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Date of birth is required' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: _decoration('Gender *', icon: Icons.wc_outlined),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) => setState(() => _gender = value ?? 'Male'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _mobile,
                        decoration: _decoration('Mobile', icon: Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        decoration: _decoration('Email', icon: Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _permanentAddress,
                        decoration: _decoration('Permanent Address', icon: Icons.home_outlined),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _presentAddress,
                        decoration: _decoration('Present Address', icon: Icons.location_on_outlined),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _areaCode,
                        decoration: _decoration('Area Code', icon: Icons.grid_view_outlined),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _constituency,
                        decoration: _decoration('Constituency', icon: Icons.map_outlined),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Registration status'),
                        subtitle: const Text('Marks whether the voter is registered and active for verification.'),
                        value: _registrationStatus,
                        onChanged: (value) => setState(() => _registrationStatus = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Eligibility status'),
                        subtitle: const Text('Controls whether the voter can cast a ballot.'),
                        value: _eligibilityStatus,
                        onChanged: (value) => setState(() => _eligibilityStatus = value),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _accountStatus,
                        decoration: _decoration('Account Status', icon: Icons.verified_user_outlined),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (value) => setState(() => _accountStatus = value ?? 'Active'),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_submitting ? 'Saving...' : 'Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_submitting)
            Container(
              color: Colors.black.withValues(alpha: 0.06),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}