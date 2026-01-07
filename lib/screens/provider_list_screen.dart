import 'package:flutter/material.dart';
import '../services/provider_service.dart';

class ProviderListScreen extends StatefulWidget {
  final String? serviceType;
  
  const ProviderListScreen({Key? key, this.serviceType}) : super(key: key);

  @override
  _ProviderListScreenState createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  final ProviderService _providerService = ProviderService();
  
  // Filters
  String _selectedSort = 'distance';
  double _maxDistance = 10.0; // km
  double _minRating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final providers = await _providerService.getAllProviders();
      
      // Apply filters
      List<Map<String, dynamic>> filtered = providers;
      
      if (widget.serviceType != null) {
        filtered = filtered.where((p) => 
          p['serviceType'].toString().toLowerCase().contains(
            widget.serviceType!.toLowerCase()
          )
        ).toList();
      }
      
      // Apply rating filter
      filtered = filtered.where((p) => 
        (p['rating'] as num) >= _minRating
      ).toList();
      
      // Sort
      filtered.sort((a, b) {
        switch (_selectedSort) {
          case 'rating':
            return (b['rating'] as num).compareTo(a['rating'] as num);
          case 'price_low':
            return (a['hourlyRate'] as num).compareTo(b['hourlyRate'] as num);
          case 'price_high':
            return (b['hourlyRate'] as num).compareTo(a['hourlyRate'] as num);
          default: // distance
            return 0; // We'll implement actual distance sort later
        }
      });

      setState(() {
        _providers = filtered;
      });
    } catch (e) {
      print('❌ Error loading providers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Service Providers'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                      SizedBox(height: 20),
                      Text(
                        'No providers found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Try adjusting your filters',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _providers.length,
                  itemBuilder: (context, index) {
                    return _buildProviderCard(_providers[index]);
                  },
                ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/provider-details',
            arguments: provider,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, color: Colors.blue),
                radius: 25,
              ),
              SizedBox(width: 15),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider['name'] ?? 'Provider',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text('${provider['rating'] ?? 0.0} ⭐'),
                          backgroundColor: Colors.amber[50],
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      provider['serviceType'] ?? 'Service',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    
                    // Location & Experience
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            provider['location']?['address'] ?? 'No address',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.work, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          '${provider['experience'] ?? 0} years experience',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        Spacer(),
                        Text(
                          'LKR ${provider['hourlyRate'] ?? 0}/hour',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
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

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Providers'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sort by
                  ListTile(
                    title: Text('Sort by'),
                    trailing: DropdownButton<String>(
                      value: _selectedSort,
                      onChanged: (value) {
                        setState(() {
                          _selectedSort = value!;
                        });
                      },
                      items: [
                        DropdownMenuItem(value: 'distance', child: Text('Nearest')),
                        DropdownMenuItem(value: 'rating', child: Text('Highest Rated')),
                        DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                        DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                      ],
                    ),
                  ),
                  
                  // Max distance
                  ListTile(
                    title: Text('Max Distance: ${_maxDistance.toInt()} km'),
                    subtitle: Slider(
                      value: _maxDistance,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      onChanged: (value) {
                        setState(() {
                          _maxDistance = value;
                        });
                      },
                    ),
                  ),
                  
                  // Min rating
                  ListTile(
                    title: Text('Minimum Rating: ${_minRating.toStringAsFixed(1)} ⭐'),
                    subtitle: Slider(
                      value: _minRating,
                      min: 0,
                      max: 5,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _minRating = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadProviders();
                  },
                  child: Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}