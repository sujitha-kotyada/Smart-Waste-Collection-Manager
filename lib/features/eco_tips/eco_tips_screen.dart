import 'package:flutter/material.dart';

class EcoTipsScreen extends StatelessWidget {
  const EcoTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00796B), Color(0xFF004D40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Sustainable Living & Waste Segregation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Responsible municipal waste management begins at source. Learn segregation protocols aligned with global sustainability standards.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SDG Alignment Section
        const Text(
          'UN Sustainable Development Goals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C2826),
          ),
        ),
        const SizedBox(height: 12),
        _buildSdgCard(
          sdgNumber: '11',
          sdgTitle: 'Sustainable Cities and Communities',
          sdgTarget:
              'Target 11.6: By 2030, reduce the adverse per capita environmental impact of cities, including by paying special attention to air quality and municipal and other waste management.',
          color: const Color(0xFFFD9D24),
          icon: Icons.location_city,
        ),
        const SizedBox(height: 12),
        _buildSdgCard(
          sdgNumber: '12',
          sdgTitle: 'Responsible Consumption and Production',
          sdgTarget:
              'Target 12.5: By 2030, substantially reduce waste generation through prevention, reduction, recycling, and reuse (the 4R framework).',
          color: const Color(0xFFBF8B2E),
          icon: Icons.autorenew,
        ),
        const SizedBox(height: 24),

        // Practical Segregation Guides
        const Text(
          'Waste Segregation Guidelines',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C2826),
          ),
        ),
        const SizedBox(height: 12),
        _buildGuideCard(
          category: 'Green Bin • Wet & Organic Waste',
          items:
              'Vegetable peels, leftover food, fruit scraps, tea bags, garden trimmings.',
          action:
              'Compost at home or hand to municipal wet waste truck for biomethanation.',
          color: const Color(0xFF2E7D32),
          icon: Icons.compost,
        ),
        const SizedBox(height: 12),
        _buildGuideCard(
          category: 'Blue Bin • Dry & Recyclables',
          items:
              'Plastic bottles, cartons, newspaper, beverage cans, clean packaging.',
          action:
              'Rinse milk & food packets before binning to prevent contamination in recycling streams.',
          color: const Color(0xFF1976D2),
          icon: Icons.recycling,
        ),
        const SizedBox(height: 12),
        _buildGuideCard(
          category: 'Red / Black Bin • Domestic Hazardous',
          items:
              'Batteries, CFL bulbs, medical waste, expired pharmaceuticals, spray cans.',
          action:
              'Wrap securely and label for specialized hazardous municipal collection.',
          color: const Color(0xFFC62828),
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        _buildGuideCard(
          category: 'E-Waste • Electronic Appliances',
          items:
              'Broken chargers, circuit boards, old phones, computers, power banks.',
          action:
              'Deposit at certified e-waste aggregation booths to prevent heavy metal groundwater contamination.',
          color: const Color(0xFF6A1B9A),
          icon: Icons.devices,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSdgCard({
    required String sdgNumber,
    required String sdgTitle,
    required String sdgTarget,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'SDG\n$sdgNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sdgTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sdgTarget,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.35,
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

  Widget _buildGuideCard({
    required String category,
    required String items,
    required String action,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Items: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: Text(
                    items,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Best Practice: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: Text(
                    action,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
