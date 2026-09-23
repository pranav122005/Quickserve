import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/geolocation_service.dart';
import '../controllers/customer_requests_controller.dart';
import 'customer_mobile_create_request_screen.dart';
import 'customer_tracking_screen.dart';

class CreateRequestDialog extends ConsumerStatefulWidget {
  const CreateRequestDialog({super.key});

  @override
  ConsumerState<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends ConsumerState<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = ServiceCategories.all.first;
  RequestPriority _selectedPriority = RequestPriority.normal;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  double? _selectedLat;
  double? _selectedLon;
  String? _selectedPresetName;

  DateTime? _preferredDateTime;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _formError;

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _formError = null;
    });

    try {
      final geoService = ref.read(geolocationServiceProvider);
      final perm = await geoService.requestPermission();

      if (perm == LocationPermissionStatus.granted) {
        final position = await geoService.getCurrentPosition();
        if (mounted && position != null) {
          setState(() {
            _selectedLat = position.latitude;
            _selectedLon = position.longitude;
            _selectedPresetName = 'Live Location';
            _addressController.text =
                'Live Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Live GPS location captured successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          setState(() => _formError = 'Could not acquire GPS fix. Please enter your address manually.');
        }
      } else if (mounted) {
        setState(() => _formError = 'Location permission is required to detect live GPS.');
      }
    } catch (e) {
      if (mounted) setState(() => _formError = 'Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectPreset(kPresetLocations.first);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _selectPreset(PresetLocation preset) {
    setState(() {
      _selectedPresetName = preset.name;
      _addressController.text = preset.address;
      _selectedLat = preset.lat;
      _selectedLon = preset.lon;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _preferredDateTime ?? now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _preferredDateTime != null
          ? TimeOfDay.fromDateTime(_preferredDateTime!)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _preferredDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    String? fullDescription = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;
    if (_preferredDateTime != null) {
      final scheduleStr = 'Preferred Schedule: ${Formatters.formatDateTime(_preferredDateTime)}';
      fullDescription = fullDescription != null ? '[$scheduleStr]\n$fullDescription' : '[$scheduleStr]';
    }

    final createdRequest = await ref.read(customerRequestsProvider.notifier).createRequest(
          category: _selectedCategory,
          title: _titleController.text.trim(),
          description: fullDescription,
          serviceAddress: _addressController.text.trim(),
          priority: _selectedPriority,
          latitude: _selectedLat,
          longitude: _selectedLon,
        );

    if (mounted) {
      if (createdRequest != null) {
        ref.read(auditServiceProvider).logRequestCreated(
          createdRequest.id,
          createdRequest.customerId,
          category: createdRequest.category,
          title: createdRequest.title,
        );

        ref.read(dispatchServiceProvider).dispatchRequest(createdRequest.id);

        Navigator.of(context).pop();

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerTrackingScreen(
              requestId: createdRequest.id,
              initialRequest: createdRequest,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request submitted and dispatch initiated!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _formError = ref.read(customerRequestsProvider).errorMessage ??
              'Failed to submit service request. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_task, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'New Service Request',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_formError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _formError!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                            ),
                          ),
                        // Category & Priority Row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: ServiceCategories.all
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<RequestPriority>(
                                initialValue: _selectedPriority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                ),
                                items: RequestPriority.values
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p.displayName),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedPriority = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Request Title',
                            hintText: 'e.g., Kitchen pipe leakage repair',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a title.';
                            }
                            if (val.trim().length < 3) {
                              return 'Title must be at least 3 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText: 'Provide details about the issue or requirements...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preferred Schedule
                        InkWell(
                          onTap: _pickDateTime,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Preferred Date & Time',
                              prefixIcon: const Icon(Icons.calendar_today_outlined),
                              suffixIcon: _preferredDateTime != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _preferredDateTime = null),
                                    )
                                  : const Icon(Icons.arrow_drop_down),
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              _preferredDateTime != null
                                  ? Formatters.formatDateTime(_preferredDateTime)
                                  : 'Select preferred service schedule (optional)',
                              style: TextStyle(
                                color: _preferredDateTime != null ? Colors.black87 : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Swiggy/Flipkart Location Preset Chips & Live Location Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Quick Location Presets',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                            ),
                            TextButton.icon(
                              onPressed: _isLocating ? null : _fetchCurrentLocation,
                              icon: _isLocating
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location, size: 16, color: Color(0xFF2563EB)),
                              label: Text(
                                _isLocating ? 'Detecting...' : 'Use Live Location',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: kPresetLocations.map((preset) {
                              final isSelected = _selectedPresetName == preset.name;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  avatar: Icon(
                                    isSelected ? Icons.check_circle : Icons.place_outlined,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF2563EB),
                                  ),
                                  label: Text(preset.name),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF2563EB),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey.shade800,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  onSelected: (_) => _selectPreset(preset),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Service Address
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Service Address',
                            hintText: 'Enter street address, landmark, or city',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.my_location, color: Color(0xFF2563EB)),
                              tooltip: 'Autofill Live GPS Location',
                              onPressed: _isLocating ? null : _fetchCurrentLocation,
                            ),
                          ),
                          maxLines: 2,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter the service location address.';
                            }
                            return null;
                          },
                        ),
                      ],
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
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Request'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
