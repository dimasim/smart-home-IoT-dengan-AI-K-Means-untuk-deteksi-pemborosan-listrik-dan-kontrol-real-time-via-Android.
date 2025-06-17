import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
  final MqttServerClient client = MqttServerClient(
      '103.172.204.63', 'flutter_client'); // MQTT Broker address
  bool isConnected = false;

  // Data variables
  bool personDetected = false;
  double temperature = 0.0;
  double humidity = 0.0;
  bool lampOn = false;
  bool fanOn = false;
  double currentUsage = 0.0;
  int wastagePredict = 0;
  String lastUpdate = '';

  // MQTT Topics
  final String mqttSensorTopic =
      "UAS24-IOT/4.33.22.0.06/sensor"; // Sensor data topic
  final String mqttLampTopic =
      "UAS24-IOT/4.33.22.0.06/lamp_on"; // Lamp control topic
  final String mqttFanTopic =
      "UAS24-IOT/4.33.22.0.06/fan_on"; // Fan control topic
  final String mqttPredictionTopic =
      "UAS24-IOT/4.33.22.0.06/prediction"; // Prediction data topic

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
      await client.connect('uas24_iot', 'uas24_iot');
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Connected to MQTT Broker');
      _subscribeToTopics();
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

  void _subscribeToTopics() {
    client.subscribe(mqttSensorTopic, MqttQos.atMostOnce);
    client.subscribe(mqttLampTopic, MqttQos.atMostOnce);
    client.subscribe(mqttFanTopic, MqttQos.atMostOnce);
    client.subscribe(mqttPredictionTopic, MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      _updateData(payload);
    });
  }

  void _updateData(String payload) {
    try {
      final Map<String, dynamic> data = json.decode(payload);

      if (data.containsKey('person_detected')) {
        setState(() {
          personDetected = data['person_detected'] == 1;
          temperature = data['temperature']?.toDouble() ?? 0.0;
          humidity = data['humidity']?.toDouble() ?? 0.0;
          lampOn = data['lamp_on'] == true;
          fanOn = data['fan_on'] == true;
          currentUsage = data['current_usage']?.toDouble() ?? 0.0;
        });
      }

      if (data.containsKey('wastage_prediction')) {
        setState(() {
          wastagePredict = data['wastage_prediction'] ?? 0;
        });
      }

      // Update timestamp as the last update time
      setState(() {
        lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    } catch (e) {
      print('Error parsing data: $e');
    }
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

  Widget _buildWastageCard() {
    final bool isWastage = wastagePredict == 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Penggunaan Listrik',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isWastage ? Icons.warning_amber : Icons.check_circle,
                  color: isWastage ? Colors.red : Colors.green,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isWastage ? 'Terdeteksi Keborosan' : 'Pemakaian Normal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isWastage ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
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
            _buildStatusItem('Lamp', lampOn, Icons.lightbulb, mqttLampTopic),
            const SizedBox(height: 8),
            _buildStatusItem('Fan', fanOn, Icons.wind_power, mqttFanTopic),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String name, bool isOn, IconData icon, String topic) {
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
          onChanged: (bool newValue) {
            setState(() {
              // Update the state locally
              if (name == 'Lamp') {
                lampOn = newValue;
              } else if (name == 'Fan') {
                fanOn = newValue;
              }
            });

            // Publish the message to the respective MQTT topic
            final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
            builder.addString(newValue ? '{"state":"ON"}' : '{"state":"OFF"}');

            if (name == 'Lamp') {
              client.publishMessage(
                  mqttLampTopic, MqttQos.atLeastOnce, builder.payload!);
            } else if (name == 'Fan') {
              client.publishMessage(
                  mqttFanTopic, MqttQos.atLeastOnce, builder.payload!);
            }
          },
        ),
      ],
    );
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
              _buildWastageCard(),
              const SizedBox(height: 16),
              _buildDeviceStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }
}
