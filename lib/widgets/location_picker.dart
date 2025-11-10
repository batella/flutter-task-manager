import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final void Function(double lat, double lon, String? address) onLocationSelected;

  const LocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool _loading = false;
  double? _lat;
  double? _lon;
  String? _address;
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLatitude;
    _lon = widget.initialLongitude;
    _address = widget.initialAddress;
    if (_address != null) {
      _addressController.text = _address!;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loading = true);
    final data = await LocationService.instance.getCurrentLocationWithAddress();
    if (mounted) {
      setState(() {
        _loading = false;
        if (data != null) {
          _lat = data['latitude'] as double?;
          _lon = data['longitude'] as double?;
          _address = data['address'] as String?;
          _addressController.text = _address ?? '';
        }
      });
    }
  }

  Future<void> _resolveAddress() async {
    final text = _addressController.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);
    final pos = await LocationService.instance.getLocationFromAddress(text);
    if (mounted) {
      setState(() {
        _loading = false;
        if (pos != null) {
          _lat = pos['latitude'];
          _lon = pos['longitude'];
          _address = text;
        }
      });
    }
  }

  void _confirm() {
    if (_lat != null && _lon != null) {
      widget.onLocationSelected(_lat!, _lon!, _address);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ou busque uma localização antes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço / Referência',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _resolveAddress(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _resolveAddress,
                icon: const Icon(Icons.check_circle),
                tooltip: 'Buscar endereço',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar minha localização atual'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!_loading && _lat != null && _lon != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Latitude: ${_lat!.toStringAsFixed(6)}'),
                    Text('Longitude: ${_lon!.toStringAsFixed(6)}'),
                    if (_address != null && _address!.isNotEmpty) Text('Endereço: $_address'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}