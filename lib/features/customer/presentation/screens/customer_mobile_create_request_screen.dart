import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/geolocation_service.dart';
import '../controllers/customer_requests_controller.dart';
import 'customer_tracking_screen.dart';

class PresetLocation {
  final String name;
  final String address;
  final double lat;
  final double lon;

  const PresetLocation({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
  });
}

const List<PresetLocation> kPresetLocations = [
  PresetLocation(
    name: 'Home (Indiranagar)',
    address: '42, 100ft Road, Indiranagar, Bengaluru - 560038',
    lat: 12.9716,
    lon: 77.6412,
  ),
  PresetLocation(
    name: 'Work (MG Road)',
    address: '15, Utility Building, MG Road, Bengaluru - 560001',
    lat: 12.9756,
    lon: 77.6066,
  ),
  PresetLocation(
    name: 'Koramangala',
    address: '88, 5th Block, Koramangala, Bengaluru - 560095',
    lat: 12.9352,
    lon: 77.6245,
  ),
  PresetLocation(
    name: 'Whitefield',
    address: '102, ITPL Main Road, Whitefield, Bengaluru - 560066',
    lat: 12.9698,
    lon: 77.7499,
  ),
  PresetLocation(
    name: 'HSR Layout',
    address: '24, 27th Main Rd, Sector 1, HSR Layout, Bengaluru - 560102',
    lat: 12.9121,
    lon: 77.6445,
  ),
];

final Map<String, List<String>> kCategoryQuickIssues = {
  'Plumbing': [
    'Tap Water Leakage',
    'Drain Pipe Blockage',
    'Washbasin Installation',
    'Flush Tank Repair',
  ],
  'Electrical': [
    'Switchboard Sparking',
    'Ceiling Fan Repair',
    'Short Circuit Check',
    'MCB Tripping Issue',
  ],
  'Cleaning': [
    'Full Home Deep Clean',
    'Bathroom Sanitization',
    'Sofa & Carpet Clean',
    'Kitchen Degreasing',
  ],
  'AC Repair': [
    'AC Servicing & Cleaning',
    'Gas Refill & Check',
    'AC Cooling Issue',
    'Water Dripping Problem',
  ],
  'Carpentry': [
    'Door Lock Replacement',
    'Cabinet Hinge Repair',
    'Furniture Assembly',
    'Wooden Shelf Fitting',
  ],
  'Moving': [
    'House Shifting Service',
    'Heavy Luggage Transport',
    'Packaging & Moving',
  ],
};

final Map<String, IconData> kCategoryIcons = {
  'Plumbing': Icons.plumbing_rounded,
  'Electrical': Icons.electrical_services_rounded,
  'Cleaning': Icons.cleaning_services_rounded,
  'AC Repair': Icons.ac_unit_rounded,
  'Carpentry': Icons.handyman_rounded,
  'Moving': Icons.local_shipping_rounded,
};

/// Step-based mobile request creation screen.
class CustomerMobileCreateRequestScreen extends ConsumerStatefulWidget {
  final String? initialCategory;

  const CustomerMobileCreateRequestScreen({super.key, this.initialCategory});

  @override
  ConsumerState<CustomerMobileCreateRequestScreen> createState() =>
      _CustomerMobileCreateRequestScreenState();
}

class _CustomerMobileCreateRequestScreenState
    extends ConsumerState<CustomerMobileCreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  late String _selectedCategory;
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

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? ServiceCategories.all.first;
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

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _formError = null;
    });

    try {
      final geoService = ref.read(geolocationServiceProvider);
      final perm = await geoService.requestPermission();

      if (perm == LocationPermissionStatus.serviceDisabled ||
          perm == LocationPermissionStatus.permanentlyDenied) {
        if (mounted) {
          setState(() {
            _formError = 'GPS disabled or permission denied. Please select a preset location.';
          });
        }
        return;
      }

      final position = await geoService.getCurrentPosition();
      if (mounted) {
        if (position != null) {
          setState(() {
            _selectedLat = position.latitude;
            _selectedLon = position.longitude;
            _selectedPresetName = 'Current GPS Location';
            _addressController.text =
                'Detected Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'Location error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
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
          try {
            ref.read(auditServiceProvider).logRequestCreated(
                  createdRequest.id,
                  createdRequest.customerId,
                  category: createdRequest.category,
                  title: createdRequest.title,
                );
          } catch (_) {}

          try {
            await ref.read(dispatchServiceProvider).dispatchRequest(createdRequest.id);
          } catch (_) {}

          if (!mounted) return;

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
              content: Text('Request submitted successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        } else {
          final errMessage = ref.read(customerRequestsProvider).errorMessage;
          setState(() {
            _isSubmitting = false;
            _formError = (errMessage != null && errMessage.isNotEmpty)
                ? errMessage
                : 'Unable to submit request. Please check your service details and try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError = 'Submission failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Category', 'Details', 'Location', 'Review'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Book a Service', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Indicator Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                children: List.generate(steps.length, (index) {
                  final isDone = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  final color = isDone || isCurrent ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1);

                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isDone ? const Color(0xFF2563EB) : (isCurrent ? const Color(0xFFEFF6FF) : Colors.white),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Text(
                                    (index + 1).toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            steps[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (index < steps.length - 1)
                          Expanded(
                            child: Divider(
                              color: isDone ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              thickness: 2,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_formError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(_formError!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                        ),
                      ],

                      if (_currentStep == 0) _buildStep0Category(),
                      if (_currentStep == 1) _buildStep1Details(),
                      if (_currentStep == 2) _buildStep2Location(),
                      if (_currentStep == 3) _buildStep3Review(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                      child: const Text('Back'),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_currentStep < 3) {
                                if (_currentStep == 1 && _titleController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter or select a service title.')),
                                  );
                                  return;
                                }
                                setState(() => _currentStep++);
                              } else {
                                _submit();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _currentStep == 3 ? 'Confirm & Submit Request' : 'Next Step',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0Category() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Choose Service Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text('Select the type of professional service you need.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: ServiceCategories.all.length,
          itemBuilder: (context, index) {
            final cat = ServiceCategories.all[index];
            final isSelected = cat == _selectedCategory;
            final icon = kCategoryIcons[cat] ?? Icons.build_rounded;

            return InkWell(
              onTap: () => setState(() => _selectedCategory = cat),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      cat,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep1Details() {
    final quickIssues = kCategoryQuickIssues[_selectedCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Service Requirement Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text('Selected Category: $_selectedCategory', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 20),

        if (quickIssues.isNotEmpty) ...[
          const Text('Quick Issue Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickIssues.map((issue) {
              final isSelected = _titleController.text == issue;
              return ChoiceChip(
                label: Text(issue),
                selected: isSelected,
                selectedColor: const Color(0xFFEFF6FF),
                onSelected: (selected) {
                  setState(() => _titleController.text = selected ? issue : '');
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller: _titleController,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            labelText: 'Service Title *',
            hintText: 'e.g., Leaking Tap Repair in Kitchen',
            prefixIcon: Icon(Icons.edit_outlined, size: 20),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a service title' : null,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            labelText: 'Description / Instructions (Optional)',
            hintText: 'Provide any specific details or access instructions...',
            prefixIcon: Icon(Icons.notes_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '3. Service Address & Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            TextButton.icon(
              onPressed: _isLocating ? null : _fetchCurrentLocation,
              icon: _isLocating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('GPS Detect'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text('Saved Preset Addresses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Column(
          children: kPresetLocations.map((preset) {
            final isSelected = _selectedPresetName == preset.name;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
              ),
              child: ListTile(
                onTap: () => _selectPreset(preset),
                leading: Icon(Icons.place_rounded, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                title: Text(preset.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
                subtitle: Text(preset.address, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _addressController,
          maxLines: 2,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            labelText: 'Full Service Address *',
            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
        ),
      ],
    );
  }

  Widget _buildStep3Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. Review & Confirm Booking',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        const Text('Review your details before requesting dispatch.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 20),

        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _reviewRow('Category', _selectedCategory, Icons.category_rounded),
                const Divider(height: 24),
                _reviewRow('Service Requirement', _titleController.text.trim(), Icons.build_rounded),
                const Divider(height: 24),
                _reviewRow('Service Address', _addressController.text.trim(), Icons.place_rounded),
                const Divider(height: 24),
                _reviewRow('Schedule', _preferredDateTime != null ? Formatters.formatDateTime(_preferredDateTime) : 'As soon as possible', Icons.event_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        SegmentedButton<RequestPriority>(
          segments: const [
            ButtonSegment(value: RequestPriority.low, label: Text('Low')),
            ButtonSegment(value: RequestPriority.normal, label: Text('Normal')),
            ButtonSegment(value: RequestPriority.high, label: Text('High')),
            ButtonSegment(value: RequestPriority.urgent, label: Text('Urgent')),
          ],
          selected: {_selectedPriority},
          onSelectionChanged: (set) => setState(() => _selectedPriority = set.first),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value.isNotEmpty ? value : 'Not specified', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }
}
