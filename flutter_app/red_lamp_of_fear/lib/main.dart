import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:red_lamp_of_fear/info_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Stopwatch stopwatch;
  late Timer t;
  bool overtime = false;

  Duration noLightDuration = const Duration(minutes: 3);
  Duration blinkDuration = const Duration(minutes: 2);

  Duration totalDuration = const Duration(minutes: 5);

  bool connected = false;
  String connectionStatus = "-";

  final flutterReactiveBle = FlutterReactiveBle();

  final Uuid serviceUuid = Uuid.parse("6d616465-6279-746f-7274-696b39323c33");
  final Uuid characteristicUuid = Uuid.parse("63616b65-6c61-6268-6172-647761726521");
  final String deviceName = "Death Blinker BLE";


  @override
  void initState() {
    super.initState();

    // Request permissions and then find the BLE device
    requestPermissions().then((granted) {
      if (granted) {
        
        findBLEDevice();
      } else {
        if (kDebugMode) {
          print("Permissions not granted. Cannot proceed with BLE scanning.");
        }
      }
    });
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    stopwatch = Stopwatch();
    t = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      setState(() {});
    });
  }

Future<bool> requestPermissions() async {
  // Request all required permissions


  Map<Permission, PermissionStatus> statuses = await [
    Permission.locationWhenInUse,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();

  // Check if all permissions are granted
  bool allGranted = statuses.values.every((status) => status.isGranted);
  if (kDebugMode) {
    print("Bluetooth Scan Permission: ${await Permission.bluetoothScan.status}");
    print("Bluetooth Connect Permission: ${await Permission.bluetoothConnect.status}");
    print("Location Permission: ${await Permission.locationWhenInUse.status}");
    
    if (!allGranted) {
      print("Some permissions were denied or not granted.");
    }
  }
    
  

  return allGranted;
}


  String deviceId = "";
  StreamSubscription? streamSubscription;
  StreamSubscription<ConnectionStateUpdate>? connection;
  QualifiedCharacteristic? characteristic;

  void findBLEDevice() {
    if (kDebugMode) {
      print("GRANTED PERMISSIONS");
    }
    streamSubscription = flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      if (kDebugMode) {
        print('Found device: ${device.name}, ID: ${device.id}');
      }
      if (device.name == deviceName) {
        deviceId = device.id;
        if (kDebugMode) {
          print('Matched device found: $deviceId');
        }
        streamSubscription?.cancel();
        connectToBLEDevice();
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('Error during scan: $error');
      }
    });
  }

 void connectToBLEDevice() {
  setState(() {
    connectionStatus = "found!";
  });
    connection = flutterReactiveBle.connectToDevice(id: deviceId).listen(
  (connectionState) {
    if (connectionState.connectionState == DeviceConnectionState.connected) {
      if (kDebugMode) {
        print('Device connected');
      }
      setState(() {
        connectionStatus = "Connected";
        connected = true;
      });
      characteristic = QualifiedCharacteristic(serviceId: serviceUuid, characteristicId: characteristicUuid, deviceId: deviceId);
      
    } else {
      if (kDebugMode) {
        print('Connection state: ${connectionState.connectionState}');
      }
      setState(() {
        connectionStatus = connectionState.connectionState.name;
        connected = false;
      });
      findBLEDevice();
    }
  },
  onError: (error) {
    if (kDebugMode) {
      print('Connection error: $error');
    }
  },
); 
  }

  @override
  void dispose() {
    closeConnection();
    super.dispose();
    
  }

  Future<void> closeConnection() async {
    if (kDebugMode) {
      print("Close Connection");
    }
    await streamSubscription?.cancel();
    await connection?.cancel();
    streamSubscription = null;
  }

  void handleStartStop() {
    if (stopwatch.isRunning) {
      stopwatch.stop();
    
      flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic!, value: [0xFE]);
    } else {
      
      stopwatch.start();
      calcTotalDuration();
    
      int nLminutes = noLightDuration.inMinutes;
      int nLseconds = noLightDuration.inSeconds - (nLminutes * 60);

      int bLminutes = blinkDuration.inMinutes;
      int bLseconds = blinkDuration.inSeconds - (bLminutes * 60);
      if(!overtime) {
        totalDuration += const Duration(milliseconds: 999);
      }
      flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic!, value: [0xF0, nLminutes, nLseconds, bLminutes, bLseconds]);
    }
  }
  void calcTotalDuration() {
    setState(() {
      totalDuration = noLightDuration + blinkDuration;
    });
  }

  void handleReset() {
    stopwatch.stop();
    stopwatch.reset();
    
    calcTotalDuration();
    setState(() {
      overtime=false;
    });
    flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic!, value: [0xFF]);
  }

  String returnFormattedText(Duration duration) {

    var milli = duration.inMilliseconds.abs();

    String seconds = ((milli ~/ 1000) % 60).toString().padLeft(2, "0");
    String minutes = ((milli ~/ 1000) ~/ 60).toString().padLeft(2, "0");
  
    return "$minutes:$seconds";
  }

  String returnTimerText() {
    Duration duration = const Duration(seconds: 5);

    if(!overtime) {
      duration = totalDuration - stopwatch.elapsed;
      if(duration.inSeconds == 0) {
        overtime = true;
        totalDuration-=const Duration(milliseconds: 999);
        //duration = stopwatch.elapsed - totalDuration + Duration(seconds: 0);
      }
    }
    else {
      duration = stopwatch.elapsed - totalDuration;
      //if(duration.inSeconds == 0) {
         //duration+=Duration(seconds: 1);
      //}
    }
      
      
    if (kDebugMode) {
      print("Time: $duration $overtime ${stopwatch.elapsed} $totalDuration");
    }
    return returnFormattedText(duration);
  }

  void _showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
        OrientationBuilder(builder: (context, orientation) {
          return GridView.count(
            crossAxisCount: orientation == Orientation.portrait ? 1 : 2,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: orientation == Orientation.portrait ? MainAxisAlignment.end : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DefaultTextStyle(
                  style: const TextStyle(color: Colors.black, fontSize: 120),
                  child: Text(returnFormattedText(stopwatch.elapsed)),
                  ),
                  DefaultTextStyle(
                  style: TextStyle(color: overtime ? Colors.red : Colors.grey, fontSize: 45),
                  child: Text("${overtime? '-' : ''}${returnTimerText()}"),
                  ),
                  const SizedBox(height: 40)
                ],
              ),
              Column(
                mainAxisAlignment: orientation == Orientation.portrait ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  // No Light Input
                OutlinedButton(
                  
                  style:  
                    const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(200, 50)),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))))
                    ),
                  onPressed: () {
                        _showDialog(
                          CupertinoTimerPicker(
                            mode: CupertinoTimerPickerMode.ms,
                            initialTimerDuration: noLightDuration,
                            onTimerDurationChanged: (Duration newDuration) {
                              setState(() {
                                noLightDuration = newDuration;
                                calcTotalDuration();
                                });
                            },
                          ),
                        );
                      }, 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [ 
                      const Text(
                        "No Light: ", 
                        style: TextStyle(fontSize: 20, color: Colors.black)),
                      Text(
                        returnFormattedText(noLightDuration), 
                        style: const TextStyle(fontSize: 22, color: Colors.black),)
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Blinking Input
                OutlinedButton(
                  style: 
                  const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(200, 50)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))))
                  ),
                  onPressed: () {
                        _showDialog(
                          CupertinoTimerPicker(
                            mode: CupertinoTimerPickerMode.ms,
                            initialTimerDuration: blinkDuration,
                            onTimerDurationChanged: (Duration newDuration) {
                              setState(() {
                                blinkDuration = newDuration;
                                calcTotalDuration();
                              });
                            },
                          ),
                        );
                      }, 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [ 
                      const Text(
                        "Blinking: ", 
                        style: TextStyle(fontSize: 20, color: Colors.black)),
                      Text(
                        returnFormattedText(blinkDuration), 
                        style: const TextStyle(fontSize: 22, color: Colors.black),)
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Start/Pause Button
                TextButton(
                  onPressed: connected ? handleStartStop: null,
                  style: const 
                  ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.greenAccent), 
                    minimumSize: WidgetStatePropertyAll(Size(200, 10)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))))
                  ),
                  child: Text(stopwatch.isRunning ? "Pause" : "Start", style: const TextStyle(color: Colors.black, fontSize: 20),),
                ),
                const SizedBox(height: 5),

                // Reset Button
                TextButton(
                  onPressed: connected ? handleReset : null,
                  style: const 
                  ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.redAccent), 
                    minimumSize: WidgetStatePropertyAll(Size(200, 10)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))))
                  ),
                  child: const Text("Reset", style: TextStyle(color: Colors.black, fontSize: 20),),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: Center(child: TextButton(onPressed: findBLEDevice, child: Text('Status: $connectionStatus'))),
                ),
                ],
              )
            ],
          );
        }),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: FloatingActionButton(
              onPressed: () => showDialog<void>(
                context: context, 
                builder: (BuildContext context) => const InfoDialog()),
              child: const Icon(Icons.question_mark_outlined),
            )),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}