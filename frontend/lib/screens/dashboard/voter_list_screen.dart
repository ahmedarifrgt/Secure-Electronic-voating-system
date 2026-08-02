import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/voter.dart';
import '../../providers/voter_provider.dart';
import '../../providers/election_provider.dart';
import 'voter_detail_screen.dart';

class VoterListScreen extends StatefulWidget {
  const VoterListScreen({super.key, this.electionId});

  final int? electionId;

  @override
  State<VoterListScreen> createState() => _VoterListScreenState();
}

class _VoterListScreenState extends State<VoterListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVoters();
  }

  Future<void> _loadVoters([String? query]) async {
    final eid = widget.electionId;
    if (eid != null) {
      await context.read<VoterProvider>().fetchVotersForElection(eid, query: query);
    } else {
      await context.read<VoterProvider>().fetchVoters(query: query);
    }
  }

  void _onSearchChanged() {
    _loadVoters(_searchController.text.trim());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoterProvider>();
    final voters = provider.voters;
    final loading = provider.loading;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voters'),
        actions: [
          if (widget.electionId != null)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Notify voters',
              onPressed: () async {
                final msg = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController();
                    return AlertDialog(
                      title: const Text('Notify voters'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(labelText: 'Message (optional)'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Send')),
                      ],
                    );
                  },
                );
                if (!mounted) return;
                if (msg == null) return;
                final eprov = context.read<ElectionProvider>();
                final ok = await eprov.notifyVoters(widget.electionId!, message: msg.isEmpty ? null : msg);
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification queued')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(eprov.error ?? 'Failed to notify')));
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or voter ID',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearchChanged(),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Expanded(
                child: Center(
                  child: Text(
                    error,
                    style: const TextStyle(color: Palette.error),
                  ),
                ),
              )
            else if (voters.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No voters found.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: voters.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final voter = voters[index];
                    return ListTile(
                      title: Text(voter.fullName ?? 'Unknown'),
                      subtitle: Text('ID: ${voter.voterId ?? '-'} · NID: ${voter.nid ?? '-'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final ok = await context.read<VoterProvider>().fetchVoterDetail(voter.voterId ?? 0);
                        if (!mounted) return;
                        if (ok) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VoterDetailScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.read<VoterProvider>().error ?? 'Failed to load voter details.'),
                              backgroundColor: Palette.error,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
