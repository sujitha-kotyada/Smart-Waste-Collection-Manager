import 'package:flutter/material.dart';

/// Core system constants for Smart Waste Collection Manager (EcoCollect).
class AppConstants {
  static const String appName = 'EcoCollect';
  static const String appTagline =
      'Smart Waste Collection & Urban Sustainability';

  // Waste Categories
  static const List<String> wasteCategories = [
    'Household Waste',
    'Plastic Waste',
    'Organic Waste',
    'Paper & Cardboard',
    'E-Waste',
    'Hazardous Waste',
    'Construction Debris',
    'Overflowing Bin',
    'Other',
  ];

  // Report Priorities
  static const List<String> priorities = ['Low', 'Medium', 'High', 'Urgent'];

  // Report Statuses
  static const String statusPending = 'Pending';
  static const String statusAssigned = 'Assigned';
  static const String statusInProgress = 'In Progress';
  static const String statusCompleted = 'Completed';
  static const String statusRejected = 'Rejected';

  static const List<String> allStatuses = [
    statusPending,
    statusAssigned,
    statusInProgress,
    statusCompleted,
    statusRejected,
  ];

  // User Roles
  static const String roleResident = 'resident';
  static const String roleWorker = 'worker';
  static const String roleAdmin = 'admin';

  // Permitted status transitions for Workers
  static const Map<String, List<String>> workerAllowedTransitions = {
    statusAssigned: [statusInProgress],
    statusInProgress: [statusCompleted],
  };

  // Permitted status transitions for Admins
  static const Map<String, List<String>> adminAllowedTransitions = {
    statusPending: [statusAssigned, statusRejected],
    statusAssigned: [statusInProgress, statusRejected],
    statusInProgress: [statusCompleted, statusRejected],
    statusCompleted: [],
    statusRejected: [statusPending],
  };

  // Category Icons & Color mappings
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Plastic Waste':
        return Icons.local_drink_outlined;
      case 'Organic Waste':
        return Icons.compost;
      case 'Paper & Cardboard':
        return Icons.newspaper;
      case 'E-Waste':
        return Icons.devices_other;
      case 'Hazardous Waste':
        return Icons.warning_amber_rounded;
      case 'Construction Debris':
        return Icons.foundation;
      case 'Overflowing Bin':
        return Icons.delete_sweep_outlined;
      case 'Household Waste':
      default:
        return Icons.delete_outline;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case statusPending:
        return const Color(0xFFE65100); // Vibrant Amber/Orange
      case statusAssigned:
        return const Color(0xFF1976D2); // Deep Blue
      case statusInProgress:
        return const Color(0xFF7B1FA2); // Purple
      case statusCompleted:
        return const Color(0xFF2E7D32); // Eco Forest Green
      case statusRejected:
        return const Color(0xFFC62828); // Crimson Red
      default:
        return Colors.grey;
    }
  }

  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return const Color(0xFFD32F2F);
      case 'High':
        return const Color(0xFFE65100);
      case 'Medium':
        return const Color(0xFFF57C00);
      case 'Low':
      default:
        return const Color(0xFF388E3C);
    }
  }
}
