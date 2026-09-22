import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/service_request.dart';
import '../controllers/admin_controller.dart';

class ManualAssignDialog extends ConsumerStatefulWidget {
  final ServiceRequest request;

  const ManualAssignDialog({super.key, required this.request});

  @override
  ConsumerState<ManualAssignDialog> createState() => _ManualAssignDialogState();
}

class _ManualAssignDialogState extends ConsumerState<ManualAssignDialog> {
  String? _selectedAgentId;
  bool _isSubmitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardProvider);
    final agents = adminState.agents;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add, color: Colors.deepPurple.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Service Agent',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Request: ${widget.request.title}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
              Text(
                'Select an available service agent:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: agents.isEmpty
                    ? Center(
                        child: Text(
                          'No registered service agents found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RadioGroup<String>(
                        groupValue: _selectedAgentId,
                        onChanged: (val) {
                          setState(() => _selectedAgentId = val);
                        },
                        child: ListView.separated(
                          itemCount: agents.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final agent = agents[index];
                            final name = agent.userProfile?.fullName.isNotEmpty == true
                                ? agent.userProfile!.fullName
                                : 'Agent (${agent.userId.substring(0, 8)})';

                            final isSelected = _selectedAgentId == agent.userId;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.deepPurple.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: agent.availability.isAvailable
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                                radius: 16,
                                child: const Icon(Icons.person, color: Colors.white, size: 18),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                'Radius: ${agent.serviceRadiusKm.toStringAsFixed(0)} km • ${agent.availability.displayName}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Radio<String>(
                                value: agent.userId,
                              ),
                              onTap: () {
                                setState(() => _selectedAgentId = agent.userId);
                              },
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_selectedAgentId == null || _isSubmitting)
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);

                            setState(() {
                              _isSubmitting = true;
                              _error = null;
                            });

                            final success = await ref
                                .read(adminDashboardProvider.notifier)
                                .assignRequest(
                                  requestId: widget.request.id,
                                  agentId: _selectedAgentId!,
                                );

                            if (!mounted) return;

                            if (success) {
                              nav.pop(true);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Agent assigned successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              setState(() {
                                _isSubmitting = false;
                                _error = ref.read(adminDashboardProvider).errorMessage ??
                                    'Failed to assign agent. (RLS policy may restrict manual assignment).';
                              });
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm Assignment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
