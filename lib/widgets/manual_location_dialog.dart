import 'package:flutter/material.dart';

class ManualLocationDialog {
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ManualLocationDialogContent();
      },
    );
  }
}

class _ManualLocationDialogContent extends StatefulWidget {
  @override
  _ManualLocationDialogContentState createState() =>
      _ManualLocationDialogContentState();
}

class _ManualLocationDialogContentState
    extends State<_ManualLocationDialogContent> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_location, color: Colors.blue),
          SizedBox(width: 10),
          Text('Enter Your Location'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please enter your location to find nearby service providers.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 20),
            
            // Address Field
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'Street address, area',
                prefixIcon: Icon(Icons.home, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            SizedBox(height: 15),
            
            // City Field
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'Your city',
                prefixIcon: Icon(Icons.location_city, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel Button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('CANCEL'),
        ),
        
        // Confirm Button
        ElevatedButton(
          onPressed: _isLoading ? null : _confirmLocation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('CONFIRM'),
        ),
      ],
    );
  }

  Future<void> _confirmLocation() async {
    if (_addressController.text.isEmpty || _cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter both address and city'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate processing
    await Future.delayed(Duration(milliseconds: 500));

    final fullAddress = '${_addressController.text}, ${_cityController.text}';
    print('Manual location entered: $fullAddress');
    
    final Map<String, dynamic> locationData = { // Explicitly type this
      'type': 'manual',
      'address': fullAddress,
      'latitude': null,
      'longitude': null,
    };
    
    Navigator.of(context).pop(locationData);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}