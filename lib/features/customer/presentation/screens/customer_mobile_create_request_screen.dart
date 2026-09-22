import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/geolocation_service.dart';
import '../controllers/customer_requests_controller.dart';

/// Pre-configured popular locations for quick one-tap selection (Swiggy / Flipkart style).
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

/// Common Quick Issue suggestions per category for fast one-tap selection.
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

/// Icons mapped per service category.
final Map<String, IconData> kCategoryIcons = {
  'Plumbing': Icons.plumbing,
  'Electrical': Icons.electric_bolt,
  'Cleaning': Icons.cleaning_services,
  'AC Repair': Icons.ac_unit,
  'Carpentry': Icons.handyman,
  'Moving': Icons.local_shipping,
};

/// Full-screen mobile service request creation with Swiggy/Flipkart style quick selection.
class CustomerMobileCreateRequestScreen extends ConsumerStatefulWidget {
  const CustomerMobileCreateRequestScreen({super.key});

  @override
  ConsumerState<CustomerMobileCreateRequestScreen> createState() =>
      _CustomerMobileCreateRequestScreenState();
}

class _CustomerMobileCreateRequestScreenState
    extends ConsumerState<CustomerMobileCreateRequestScreen> {
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

  @override
  void initState() {
    super.initState();
    // Default to first preset location for easy user experience
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

      if (perm == LocationPermissionStatus.serviceDisabled) {
        if (mounted) {
          _showLocationPrompt(
            title: 'Location Disabled',
            message: 'Please enable GPS on your device to autofill your address.',
            actionLabel: 'Open Settings',
            onAction: () => geoService.openLocationSettings(),
          );
        }
        return;
      }

      if (perm == LocationPermissionStatus.permanentlyDenied) {
        if (mounted) {
          _showLocationPrompt(
            title: 'Permission Required',
            message: 'Location permission is permanently denied. Please enable it in App Settings.',
            actionLabel: 'Open Settings',
            onAction: () => geoService.openAppSettings(),
          );
        }
        return;
      }

      if (perm != LocationPermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _formError = 'Location permission is required to detect your location.';
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current GPS location captured!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _formError = 'Could not acquire GPS fix. Please select a preset location.';
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

  void _showLocationPrompt({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully! View status in your requests list.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _formError = ref.read(customerRequestsProvider).errorMessage ??
              'Failed to submit request. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quickIssues = kCategoryQuickIssues[_selectedCategory] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Service', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // -------------------------------------------------------------
                // 1. SELECT SERVICE CATEGORY (Visual Icon Chips)
                // -------------------------------------------------------------
                Text(
                  'Select Service',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ServiceCategories.all.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = ServiceCategories.all[index];
                      final isSelected = cat == _selectedCategory;
                      final icon = kCategoryIcons[cat] ?? Icons.build;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                            _titleController.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 84,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade800,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 2. QUICK ISSUE SUGGESTIONS (One-Tap Selection)
                // -------------------------------------------------------------
                Text(
                  'What do you need help with?',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickIssues.map((issue) {
                    final isSelected = _titleController.text == issue;
                    return ChoiceChip(
                      label: Text(issue),
                      selected: isSelected,
                      selectedColor: Colors.blue.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade800,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _titleController.text = selected ? issue : '';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Service Requirement / Title *',
                    hintText: 'e.g. Leaking Tap in Kitchen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Title is required';
                    if (v.trim().length < 3) return 'Title must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Details (Optional)',
                    hintText: 'Add instructions for the service agent...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 3. SWIGGY / FLIPKART STYLE LOCATION SELECTOR
                // -------------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Service Location',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _isLocating ? null : _fetchCurrentLocation,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: const Text('Use Current GPS'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Preset Location Chips
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

                // Service Address Input (Clean Text Field - NO Coordinates displayed!)
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Full Service Address *',
                    hintText: 'Flat / House No., Street, Area, City',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on, color: Color(0xFF2563EB)),
                  ),
                  maxLines: 2,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Service address is required';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 4. PREFERRED SCHEDULE & PRIORITY SELECTOR
                // -------------------------------------------------------------
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Preferred Schedule',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      suffixIcon: _preferredDateTime != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _preferredDateTime = null),
                            )
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _preferredDateTime != null
                          ? Formatters.formatDateTime(_preferredDateTime)
                          : 'As soon as possible (Default)',
                      style: TextStyle(
                        color: _preferredDateTime != null ? Colors.black87 : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Urgency Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                SegmentedButton<RequestPriority>(
                  segments: const [
                    ButtonSegment(value: RequestPriority.low, label: Text('Low')),
                    ButtonSegment(value: RequestPriority.normal, label: Text('Normal')),
                    ButtonSegment(value: RequestPriority.high, label: Text('High')),
                    ButtonSegment(value: RequestPriority.urgent, label: Text('Urgent')),
                  ],
                  selected: {_selectedPriority},
                  onSelectionChanged: (set) {
                    setState(() => _selectedPriority = set.first);
                  },
                ),
                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // SUBMIT BUTTON
                // -------------------------------------------------------------
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Confirm & Find Service Agent',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
