/// Models verified operational stats alongside transparent SDG impact estimations.
class EnvironmentalImpact {
  final int totalReports;
  final int completedReports;
  final int inProgressReports;
  final int pendingReports;

  // Defensible, clearly-labeled estimations (based on verified completed collections)
  final double estimatedKgDiverted;
  final double estimatedKgCo2Avoided;
  final int plasticItemsRescued;

  const EnvironmentalImpact({
    required this.totalReports,
    required this.completedReports,
    required this.inProgressReports,
    required this.pendingReports,
    required this.estimatedKgDiverted,
    required this.estimatedKgCo2Avoided,
    required this.plasticItemsRescued,
  });

  /// Assumptions benchmark:
  /// - Only *completed* collections count toward diverted waste.
  /// - Municipal estimates average ~5.0 kg per collected bin/report.
  /// - Landfill diversion saves approximately 0.72 kg CO2 equivalent per kg diverted (EPA WARM model benchmark).
  /// - Plastic categories average ~25 single-use containers/items per pickup batch.
  factory EnvironmentalImpact.calculate({
    required int total,
    required int completed,
    required int inProgress,
    required int pending,
    int completedPlasticReports = 0,
    int completedOrganicReports = 0,
  }) {
    // 5.2 kg average collection weight per completed report
    final divertedKg = completed * 5.2;
    // 0.72 kg CO2e saved per kg diverted from open dumping/landfills
    final co2Avoided = divertedKg * 0.72;
    // ~30 plastic units per completed plastic report
    final plasticUnits = completedPlasticReports * 30;

    return EnvironmentalImpact(
      totalReports: total,
      completedReports: completed,
      inProgressReports: inProgress,
      pendingReports: pending,
      estimatedKgDiverted: double.parse(divertedKg.toStringAsFixed(1)),
      estimatedKgCo2Avoided: double.parse(co2Avoided.toStringAsFixed(1)),
      plasticItemsRescued: plasticUnits,
    );
  }
}
