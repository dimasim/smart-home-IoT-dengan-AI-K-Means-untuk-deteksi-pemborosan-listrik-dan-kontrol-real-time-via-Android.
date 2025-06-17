import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late MqttServerClient client;
  String suhu = '-';
  String kelembapan = '-';
  bool isDeviceOn = false;

  @override
  void initState() {
    super.initState();
    _connectToMQTT();
  }

  Future<void> _connectToMQTT() async {
    client = MqttServerClient('192.168.5.164', '');
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs('uas24_iot', 'uas24_iot')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Connected to MQTT broker!');
      _subscribeToTopics();
    } else {
      print('Failed to connect, status: ${client.connectionStatus}');
    }
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker!');
  }

  void _subscribeToTopics() {
    client.subscribe('UAS24-IOT/4.33.22.0.06/SUHU', MqttQos.atMostOnce);
    client.subscribe('UAS24-IOT/4.33.22.0.06/KELEMBAPAN', MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final message = c[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      setState(() {
        if (c[0].topic == 'UAS24-IOT/4.33.22.0.06/SUHU') {
          suhu = payload;
        } else if (c[0].topic == 'UAS24-IOT/4.33.22.0.06/KELEMBAPAN') {
          kelembapan = payload;
        }
      });
    });
  }

  void _sendDeviceStatus() {
    final message = isDeviceOn ? '1' : '0';
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.publishMessage(
        'UAS24-IOT/Status',
        MqttQos.atMostOnce,
        builder.payload!,
      );
      print('Sent device status: $message');
    } else {
      print('Failed to send, MQTT not connected!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: ListTile(
                title: Text('Suhu', style: TextStyle(fontSize: 20)),
                trailing: Text('$suhu °C', style: TextStyle(fontSize: 24)),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 4,
              child: ListTile(
                title: Text('Kelembapan', style: TextStyle(fontSize: 20)),
                trailing: Text('$kelembapan %', style: TextStyle(fontSize: 24)),
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Device Status: ', style: TextStyle(fontSize: 18)),
                Switch(
                  value: isDeviceOn,
                  onChanged: (value) {
                    setState(() {
                      isDeviceOn = value;
                      _sendDeviceStatus();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
