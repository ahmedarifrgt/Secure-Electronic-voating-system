import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/candidate.dart';
import '../../providers/election_provider.dart';

class CandidateListScreen extends StatefulWidget {
  const CandidateListScreen({super.key, required this.electionId});

  final int electionId;

  @override
  State<CandidateListScreen> createState() => _CandidateListScreenState();
}

class _CandidateListScreenState extends State<CandidateListScreen> {
  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    await context.read<ElectionProvider>().fetchCandidates(widget.electionId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectionProvider>();
    final candidates = provider.candidates;
    final loading = provider.loading;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Candidates')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(
                child: Center(child: Text(error, style: const TextStyle(color: Palette.error))),
              )
            else if (candidates.isEmpty)
              const Expanded(child: Center(child: Text('No candidates found.')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = candidates[index];
                    return ListTile(
                      title: Text(c.name ?? 'Unnamed'),
                      subtitle: Text('${c.party ?? '-'} · ${c.constituency ?? '-'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCandidateDetail(c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCandidateDetail(Candidate c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.name ?? 'Candidate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Party: ${c.party ?? '-'}'),
            const SizedBox(height: 8),
            Text('Symbol: ${c.symbol ?? '-'}'),
            const SizedBox(height: 8),
            Text('Area code: ${c.areaCode ?? '-'}'),
            const SizedBox(height: 8),
            Text('Constituency: ${c.constituency ?? '-'}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
