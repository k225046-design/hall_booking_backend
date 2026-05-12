// ─────────────────────────────────────────────
//  photographer.dart
//  Drop this file in:  lib/features/photographer/
//
//  Contains:
//   1. PhotographerModel
//   2. PhotographerService  (API calls)
//   3. PhotographerListScreen  (hall ke photographers browse karo)
//   4. PhotographerCard  (reusable widget)
//   5. PhotographerDetailScreen
// ─────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── CHANGE THIS to your actual backend URL ───
const String _baseUrl = 'https://hallbooking.pythonanywhere.com';

// =================================================
//  1. MODEL
// =================================================

class PhotographerModel {
  final int photographerId;
  final String name;
  final String phone;
  final String email;
  final String city;
  final int experienceYears;
  final double pricePerDay;
  final String portfolioUrl;
  final String description;
  final bool isAvailable;
  final List<int> hallIds;

  const PhotographerModel({
    required this.photographerId,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.experienceYears,
    required this.pricePerDay,
    required this.portfolioUrl,
    required this.description,
    required this.isAvailable,
    required this.hallIds,
  });

  factory PhotographerModel.fromJson(Map<String, dynamic> json) {
    return PhotographerModel(
      photographerId: json['photographer_id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      city: json['city'] as String? ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      pricePerDay: (json['price_per_day'] as num?)?.toDouble() ?? 0.0,
      portfolioUrl: json['portfolio_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      hallIds: (json['hall_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'photographer_id': photographerId,
        'name': name,
        'phone': phone,
        'email': email,
        'city': city,
        'experience_years': experienceYears,
        'price_per_day': pricePerDay,
        'portfolio_url': portfolioUrl,
        'description': description,
        'is_available': isAvailable,
        'hall_ids': hallIds,
      };
}

// =================================================
//  2. SERVICE
// =================================================

class PhotographerService {
  // Sab photographers fetch karo (optional filters)
  static Future<List<PhotographerModel>> getPhotographers({
    String? city,
    int? hallId,
    bool? available,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (hallId != null) params['hall_id'] = hallId.toString();
    if (available != null) params['available'] = available.toString();

    final uri = Uri.parse('$_baseUrl/photographers')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => PhotographerModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load photographers');
  }

  // Ek hall ke photographers
  static Future<List<PhotographerModel>> getHallPhotographers(
      int hallId) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/halls/$hallId/photographers'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => PhotographerModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load hall photographers');
  }

  // Single photographer
  static Future<PhotographerModel> getPhotographer(int id) async {
    final response =
        await http.get(Uri.parse('$_baseUrl/photographers/$id'));
    if (response.statusCode == 200) {
      return PhotographerModel.fromJson(json.decode(response.body));
    }
    throw Exception('Photographer not found');
  }
}

// =================================================
//  3. PHOTOGRAPHER CARD  (reusable widget)
// =================================================

class PhotographerCard extends StatelessWidget {
  final PhotographerModel photographer;
  final bool isSelected;
  final VoidCallback? onTap;

  const PhotographerCard({
    super.key,
    required this.photographer,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFB6465F) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFB6465F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Color(0xFFB6465F), size: 30),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            photographer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Color(0xFFB6465F), size: 22),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          photographer.city,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star, size: 13, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          '${photographer.experienceYears} yrs exp',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PKR ${photographer.pricePerDay.toStringAsFixed(0)} / day',
                      style: const TextStyle(
                        color: Color(0xFFB6465F),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================
//  4. PHOTOGRAPHER LIST SCREEN
//     Usage: Push this screen from Hall Detail page
//     Pass hallId to show only relevant photographers
// =================================================

class PhotographerListScreen extends StatefulWidget {
  /// Pass hallId to filter by hall, or null to show all
  final int? hallId;

  /// If used inside booking flow, pass callback to get selected photographer
  final void Function(PhotographerModel?)? onPhotographerSelected;

  /// Already selected photographer (to restore selection state)
  final PhotographerModel? selectedPhotographer;

  const PhotographerListScreen({
    super.key,
    this.hallId,
    this.onPhotographerSelected,
    this.selectedPhotographer,
  });

  @override
  State<PhotographerListScreen> createState() =>
      _PhotographerListScreenState();
}

class _PhotographerListScreenState extends State<PhotographerListScreen> {
  List<PhotographerModel> _photographers = [];
  bool _loading = true;
  String? _error;
  PhotographerModel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedPhotographer;
    _loadPhotographers();
  }

  Future<void> _loadPhotographers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = widget.hallId != null
          ? await PhotographerService.getHallPhotographers(widget.hallId!)
          : await PhotographerService.getPhotographers(available: true);
      setState(() {
        _photographers = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleSelect(PhotographerModel p) {
    setState(() {
      // Dobara tap karne se deselect ho jata hai
      _selected = (_selected?.photographerId == p.photographerId) ? null : p;
    });
    widget.onPhotographerSelected?.call(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          'Select Photographer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          if (_selected != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Color(0xFFB6465F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _photographers.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      // Skip button (photographer optional hai)
      bottomNavigationBar: widget.onPhotographerSelected != null
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton(
                  onPressed: () {
                    widget.onPhotographerSelected?.call(null);
                    Navigator.pop(context, null);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Skip — No Photographer',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        if (_selected != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFB6465F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFFB6465F), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selected!.name} selected — PKR ${_selected!.pricePerDay.toStringAsFixed(0)}/day',
                    style: const TextStyle(
                      color: Color(0xFFB6465F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: _photographers.length,
            itemBuilder: (context, index) {
              final p = _photographers[index];
              return PhotographerCard(
                photographer: p,
                isSelected: _selected?.photographerId == p.photographerId,
                onTap: () {
                  _toggleSelect(p);
                  // Detail page bhi open karo on long press
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong'),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadPhotographers,
                child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No photographers available\nfor this hall.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
}

// =================================================
//  5. PHOTOGRAPHER DETAIL SCREEN
//     Usage: Navigator.push to this screen
// =================================================

class PhotographerDetailScreen extends StatelessWidget {
  final PhotographerModel photographer;

  const PhotographerDetailScreen({
    super.key,
    required this.photographer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: Text(photographer.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              color: const Color(0xFFB6465F).withOpacity(0.08),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB6465F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    photographer.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photographer.city,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statBox(
                    icon: Icons.work_outline,
                    label: 'Experience',
                    value: '${photographer.experienceYears} yrs',
                  ),
                  const SizedBox(width: 12),
                  _statBox(
                    icon: Icons.currency_rupee,
                    label: 'Per Day',
                    value:
                        'PKR ${photographer.pricePerDay.toStringAsFixed(0)}',
                  ),
                  const SizedBox(width: 12),
                  _statBox(
                    icon: Icons.check_circle_outline,
                    label: 'Status',
                    value: photographer.isAvailable
                        ? 'Available'
                        : 'Unavailable',
                    valueColor: photographer.isAvailable
                        ? Colors.green
                        : Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            _section(
              title: 'About',
              child: Text(
                photographer.description.isNotEmpty
                    ? photographer.description
                    : 'No description provided.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),

            // Contact info
            _section(
              title: 'Contact',
              child: Column(
                children: [
                  _contactRow(Icons.phone, photographer.phone),
                  if (photographer.email.isNotEmpty)
                    _contactRow(Icons.email, photographer.email),
                  if (photographer.portfolioUrl.isNotEmpty)
                    _contactRow(Icons.link, photographer.portfolioUrl),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Select button (return to previous screen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: photographer.isAvailable
                      ? () => Navigator.pop(context, photographer)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB6465F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Select This Photographer',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
      {required IconData icon,
      required String label,
      required String value,
      Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFB6465F), size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: valueColor ?? Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB6465F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// =================================================
//  HOW TO USE IN BOOKING FLOW
//  (Paste this logic in your existing booking screen)
// =================================================

/*

// 1. State variables apne booking screen mein add karo:
PhotographerModel? _selectedPhotographer;

// 2. Photographer select karne ka button:
ElevatedButton(
  onPressed: () async {
    final result = await Navigator.push<PhotographerModel?>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerListScreen(
          hallId: widget.hallId,  // current hall ki ID
          selectedPhotographer: _selectedPhotographer,
          onPhotographerSelected: (p) => setState(() => _selectedPhotographer = p),
        ),
      ),
    );
    if (result != null) setState(() => _selectedPhotographer = result);
  },
  child: Text(_selectedPhotographer == null
      ? 'Add Photographer (Optional)'
      : '📷 ${_selectedPhotographer!.name}'),
),

// 3. Booking API call mein photographer_id add karo:
final body = {
  'hall_id': hallId,
  'customer_id': customerId,
  'booking_date': selectedDate,
  'guest_count': guestCount,
  if (_selectedPhotographer != null)
    'photographer_id': _selectedPhotographer!.photographerId,
  // ... baaki fields
};

*/