import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/waste_report.dart';
import '../../models/app_user.dart';
import '../../repositories/waste_report_repository.dart';

class ReportWasteDialog extends StatefulWidget {
  final AppUser user;
  final WasteReportRepository repository;

  const ReportWasteDialog({
    super.key,
    required this.user,
    required this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUser user,
    required WasteReportRepository repository,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportWasteDialog(user: user, repository: repository),
    );
  }

  @override
  State<ReportWasteDialog> createState() => _ReportWasteDialogState();
}

class _ReportWasteDialogState extends State<ReportWasteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = AppConstants.wasteCategories.first;
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final newReport = WasteReport(
      id: 'REP-${now.millisecondsSinceEpoch.toString().substring(7)}',
      reporterId: widget.user.uid,
      reporterName: widget.user.displayName,
      wasteCategory: _selectedCategory,
      location: _locationController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      status: AppConstants.statusPending,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await widget.repository.createReport(newReport);
      if (mounted) {
        Navigator.pop(context);
        final isCloud = widget.repository.isUsingCloudFirestore;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCloud
                        ? 'Report #${newReport.id} saved to Cloud Firestore!'
                        : '[Demo Sandbox] Report #${newReport.id} saved locally in memory.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            content: Text('Submission Failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_location_alt,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Waste Incident',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Notify municipal workers for swift collection',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // Waste Category
                  const Text(
                    'Waste Category *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: AppConstants.wasteCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(
                              AppConstants.getCategoryIcon(cat),
                              size: 18,
                              color: const Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 10),
                            Text(cat),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Location
                  const Text(
                    'Collection Location *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. 5th Cross Road, Sector 3, Near Bus Shelter',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location, size: 20),
                        tooltip: 'Insert sample location',
                        onPressed: () {
                          _locationController.text =
                              'Main Street, Sector 2, Central Park Gate 1';
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Location is required';
                      }
                      if (val.trim().length < 4) {
                        return 'Please provide a more descriptive location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Priority Level
                  const Text(
                    'Urgency / Priority',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: AppConstants.priorities.map((pri) {
                      final isSelected = _selectedPriority == pri;
                      final color = AppConstants.getPriorityColor(pri);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedPriority = pri),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  pri,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected ? color : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description / Landmark Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe volume, obstruction, or special handling instructions...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Submit Report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
