import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const IoTDashboard(),
    );
  }
}

class IoTDashboard extends StatefulWidget {
  const IoTDashboard({Key? key}) : super(key: key);

  @override
  State<IoTDashboard> createState() => _IoTDashboardState();
}

class _IoTDashboardState extends State<IoTDashboard> {
  final MqttServerClient client =
      MqttServerClient('192.168.10.190', 'flutter_client');
  bool isConnected = false;

  // Data variables
  bool personDetected = false;
  double temperature = 0.0;
  bool lampOn = false;
  bool fanOn = false;
  double currentUsage = 0.0;
  String lastUpdate = '';
  double humidity = 0.0;
  double prediction = 0.0;
  double wattagePredict = 0.0;

  @override
  void initState() {
    super.initState();
    _connectToMqtt();
  }

  Future<void> _connectToMqtt() async {
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.port = 1883;

    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect('uas24_dimas', 'uas24_dimas');
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Connected to MQTT Broker');
      _subscribeToTopic();
    } else {
      print('Connection failed');
      client.disconnect();
    }
  }

  void _onConnected() {
    setState(() => isConnected = true);
  }

  void _onDisconnected() {
    setState(() => isConnected = false);
  }

  void _onSubscribed(String topic) {
    print('Subscribed to: $topic');
  }

  void _subscribeToTopic() {
    const topic = 'UAS24-IOT/4.33.22.0.06';
    client.subscribe(topic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      _updateData(payload);
    });
  }

  void _updateData(String payload) {
    try {
      final data = json.decode(payload);
      setState(() {
        personDetected = data['person_detected'] == 1;
        temperature = data['temperature'].toDouble();
        lampOn = data['lamp_on'] == 1;
        fanOn = data['fan_on'] == 1;
        currentUsage = data['current_usage'].toDouble();
        humidity = data['kelembapan']?.toDouble() ?? 0.0;
        prediction = data['prediction']?.toDouble() ?? 0.0;
        wattagePredict = data['wattage_prediction']?.toDouble() ?? 0.0;
        lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Dashboard'),
        actions: [
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(isConnected ? 'Connected' : 'Disconnected'),
              backgroundColor: isConnected ? Colors.green : Colors.red,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _connectToMqtt,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLastUpdateCard(),
              const SizedBox(height: 16),
              _buildSensorGrid(),
              const SizedBox(height: 16),
              _buildPredictionCard(),
              const SizedBox(height: 16),
              _buildDeviceStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastUpdateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Last Update:'),
            Text(lastUpdate,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildSensorCard(
          'Temperature',
          '$temperature°C',
          Icons.thermostat,
          Colors.orange,
        ),
        _buildSensorCard(
          'Humidity',
          '$humidity%',
          Icons.water_drop,
          Colors.blue,
        ),
        _buildSensorCard(
          'Current Usage',
          '${currentUsage.toStringAsFixed(2)}A',
          Icons.electric_bolt,
          Colors.purple,
        ),
        _buildSensorCard(
          'Motion',
          personDetected ? 'Detected' : 'Not Detected',
          Icons.motion_photos_on,
          personDetected ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildPredictionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predictions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.timeline, color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    const Text('Temperature Prediction'),
                    Text(
                      '${prediction.toStringAsFixed(2)}°C',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.electric_bolt,
                        color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    const Text('Wattage Prediction'),
                    Text(
                      '${wattagePredict.toStringAsFixed(2)}W',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusItem('Lamp', lampOn, Icons.lightbulb),
            const SizedBox(height: 8),
            _buildStatusItem('Fan', fanOn, Icons.wind_power),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String name, bool isOn, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: isOn ? Colors.amber : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(name),
        const Spacer(),
        Switch(
          value: isOn,
          onChanged: null, // Read-only switch
        ),
      ],
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }
}
