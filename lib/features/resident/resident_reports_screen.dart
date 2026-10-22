import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/waste_report.dart';
import '../../models/app_user.dart';
import '../../repositories/waste_report_repository.dart';
import 'report_waste_dialog.dart';
import 'report_detail_sheet.dart';

class ResidentReportsScreen extends StatefulWidget {
  final AppUser user;
  final WasteReportRepository repository;
  final bool showAllReports;

  const ResidentReportsScreen({
    super.key,
    required this.user,
    required this.repository,
    this.showAllReports = false,
  });

  @override
  State<ResidentReportsScreen> createState() => _ResidentReportsScreenState();
}

class _ResidentReportsScreenState extends State<ResidentReportsScreen> {
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'Newest';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<WasteReport>>(
        stream: widget.showAllReports
            ? widget.repository.streamAllReports()
            : widget.repository.streamUserReports(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load reports',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allReports = snapshot.data ?? [];

          // Filter by status
          var filtered = allReports.where((r) {
            if (_selectedStatus != 'All' && r.status != _selectedStatus) {
              return false;
            }
            if (_selectedCategory != 'All' &&
                r.wasteCategory != _selectedCategory) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchesLoc = r.location.toLowerCase().contains(q);
              final matchesDesc = r.description.toLowerCase().contains(q);
              final matchesCat = r.wasteCategory.toLowerCase().contains(q);
              final matchesId = r.id.toLowerCase().contains(q);
              if (!matchesLoc && !matchesDesc && !matchesCat && !matchesId) {
                return false;
              }
            }
            return true;
          }).toList();

          // Sort
          if (_sortBy == 'Newest') {
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else if (_sortBy == 'Oldest') {
            filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          } else if (_sortBy == 'Priority') {
            int pVal(String p) =>
                p == 'Urgent' ? 4 : (p == 'High' ? 3 : (p == 'Medium' ? 2 : 1));
            filtered.sort(
              (a, b) => pVal(b.priority).compareTo(pVal(a.priority)),
            );
          }

          return Column(
            children: [
              // Header Controls (Search & Filters)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search reports by location, category, ID...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', _selectedStatus == 'All', (
                            val,
                          ) {
                            setState(() => _selectedStatus = 'All');
                          }),
                          ...AppConstants.allStatuses.map((st) {
                            return _buildFilterChip(st, _selectedStatus == st, (
                              val,
                            ) {
                              setState(
                                () => _selectedStatus = val ? st : 'All',
                              );
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Filter Summary & Sort Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? "report" : "reports"} found',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _selectedCategory,
                          isDense: true,
                          underline: const SizedBox(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                          items: ['All', ...AppConstants.wasteCategories].map((
                            c,
                          ) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c == 'All' ? 'All Types' : c),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Sort: ',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          underline: const SizedBox(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                          items: ['Newest', 'Oldest', 'Priority'].map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _sortBy = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Reports List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching reports',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try clearing filters or search terms',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final report = filtered[index];
                          return _buildReportCard(report);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        onPressed: () => ReportWasteDialog.show(
          context,
          user: widget.user,
          repository: widget.repository,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Report Waste'),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    ValueChanged<bool> onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: const Color(0xFFE8F5E9),
        checkmarkColor: const Color(0xFF1B5E20),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(WasteReport report) {
    final statusColor = AppConstants.getStatusColor(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ReportDetailSheet.show(context, report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Icon(
                      AppConstants.getCategoryIcon(report.wasteCategory),
                      color: const Color(0xFF1B5E20),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.wasteCategory,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'ID: #${report.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      report.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              if (report.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormatter.format(report.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.getPriorityColor(
                            report.priority,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.priority,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.getPriorityColor(
                              report.priority,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
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
