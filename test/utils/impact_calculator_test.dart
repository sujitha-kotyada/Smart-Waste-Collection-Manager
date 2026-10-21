import 'package:flutter_test/flutter_test.dart';
import 'package:smart_waste_collection_manager/core/utils/impact_calculator.dart';

void main() {
  group('SDG Impact Calculator Tests', () {
    test('Calculates kg diverted only from completed collections', () {
      final impact = EnvironmentalImpact.calculate(
        total: 10,
        completed: 4,
        inProgress: 3,
        pending: 3,
        completedPlasticReports: 2,
      );

      // 4 completed * 5.2 kg = 20.8 kg
      expect(impact.estimatedKgDiverted, 20.8);
      // 20.8 kg * 0.72 = 14.98 ~ 15.0 kg CO2e
      expect(impact.estimatedKgCo2Avoided, 15.0);
      // 2 plastic reports * 30 units = 60
      expect(impact.plasticItemsRescued, 60);
      expect(impact.completedReports, 4);
    });

    test('Zero completed reports results in zero diverted claims', () {
      final impact = EnvironmentalImpact.calculate(
        total: 5,
        completed: 0,
        inProgress: 2,
        pending: 3,
      );

      expect(impact.estimatedKgDiverted, 0.0);
      expect(impact.estimatedKgCo2Avoided, 0.0);
      expect(impact.plasticItemsRescued, 0);
    });
  });
}
