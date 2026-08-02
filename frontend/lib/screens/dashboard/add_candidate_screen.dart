import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/election.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/election_provider.dart';

class AddCandidateScreen extends StatefulWidget {
  const AddCandidateScreen({super.key});

  @override
  State<AddCandidateScreen> createState() => _AddCandidateScreenState();
}

class _AddCandidateScreenState extends State<AddCandidateScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedElectionId;
  final _nameCtrl = TextEditingController();
  final _partyCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _constituencyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadElections();
  }

  Future<void> _loadElections() async {
    await context.read<DashboardProvider>().fetchElections();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _partyCtrl.dispose();
    _symbolCtrl.dispose();
    _areaCtrl.dispose();
    _constituencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final electionId = _selectedElectionId;
    if (electionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an election')));
      return;
    }

    final provider = context.read<ElectionProvider>();
    final success = await provider.addCandidate(
      electionId: electionId,
      name: _nameCtrl.text.trim(),
      party: _partyCtrl.text.trim().isEmpty ? null : _partyCtrl.text.trim(),
      symbol: _symbolCtrl.text.trim().isEmpty ? null : _symbolCtrl.text.trim(),
      areaCode: _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
      constituency: _constituencyCtrl.text.trim().isEmpty ? null : _constituencyCtrl.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate added')));
      Navigator.pop(context);
    } else {
      final err = provider.error ?? 'Failed to add candidate';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final elections = dashboard.elections;
    final loading = dashboard.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Candidate')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Election'),
                      items: elections
                          .map((e) => DropdownMenuItem(value: e.electionId, child: Text(e.name)))
                          .toList(),
                      value: _selectedElectionId,
                      onChanged: (v) => setState(() => _selectedElectionId = v),
                      validator: (v) => v == null ? 'Select an election' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter candidate name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _partyCtrl,
                      decoration: const InputDecoration(labelText: 'Party'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _symbolCtrl,
                      decoration: const InputDecoration(labelText: 'Symbol'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaCtrl,
                      decoration: const InputDecoration(labelText: 'Area code'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _constituencyCtrl,
                      decoration: const InputDecoration(labelText: 'Constituency'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: Palette.success),
                      child: const Text('Add Candidate'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
