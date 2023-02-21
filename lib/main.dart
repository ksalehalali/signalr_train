import 'dart:async';
import 'package:background_location/background_location.dart';
import 'package:drop_down_list/drop_down_list.dart';
import 'package:drop_down_list/model/selected_list_item.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:location/location.dart' as loc;

import 'distance_calculator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

String choosenBusId = "";
bool chooseDone = false;
double latitudeNew =0.0;
double longitudeNew =0.0;
double latitudeOld =0.0;
double longitudeOld =0.0;

class _MyHomePageState extends State<MyHomePage> {

  void _incrementCounter()async {
  }

  List busses = [];
  List< DropdownMenuItem> dropdownItems = [];
  bool gotItems = true;

  String selectedBus = "select";
  HubConnection? connection;
  final liveTransactionServerUrl = "https://route.click68.com/chatHub";

  Future<void> signalRInit() async {
    connection = HubConnectionBuilder().withUrl(liveTransactionServerUrl,
        HttpConnectionOptions(
          // accessTokenFactory: () async => await liveTransactionAccessToken,
            transport: HttpTransportType.webSockets,
            logging: (level, message){
              if(message.contains('HubConnection connected successfully')){
               print('connected successfully');
              }
              print("SignalR Level: $level, Message: ${message.toString()}");
            }
        )).build();

    connection?.serverTimeoutInMilliseconds = Duration(hours: 90).inMilliseconds;
    connection?.onclose((exception) {

      print("onclose.. Exception: $exception");
    });
    connection?.onreconnected((connectionId){

      print("------- ConnectionId: $connectionId");
    });

    //Transactions count listener
    connection?.on('PaymentCount', (message) {
      print("----- onPaymentCount.. Message: ${message!.first}");
    });
    //Transactions value listener
    connection?.on('PaymentValueCount', (message) {
      print("------onPaymentValueCount.. Message: ${message!.first}");
    });
    //Transactions listener
    connection?.on('PaymentLive', (message) async {
      print("-------- onPaymentLive.. Message: ${message!.first}");

      // bool canVibrate = await Vibrate.canVibrate;
      //if (canVibrate == true) {Vibrate.feedback(FeedbackType.success);}
    });

    connection?.on('ListBusMap', (message) async {
      print("-------- GetListBusMap ..... Message: ${message!.first}");
      _listOfBusses.clear();
      busses = message.first;
      for (int i =0; i< message.first.length; i++) {
        _listOfBusses.add( SelectedListItem(
          name:message.first[i]['plateNumber'],
          value: message.first[i]['busID'],
          isSelected: false,
        ),);
      print("plat number ${message.first[i]['plateNumber']} -- lat = ${message.first[i]['latitude2']} -lng = ${message.first[i]['longitude2']} -- Bus Id ${message.first[i]['busID']}");
      gotItems =true;

      }
      setState(() {});
    });



    await connection?.start();
    receiveMessage();
  }

  sendMessage()async {
   var send = await connection?.invoke('SendUserLocation', args: [{"UserID":"a4ef8734-83c4-4c17-a285-a153d40cdcd0","Longitude":47.986532309399095,"Latitude":29.382033051274004,}]);
   print("result:: $send");
  }

  sendMessageBus(double lat ,double long)async {
    print("lat: ^^^......^^^ $lat long: $long");
    var send = await connection?.invoke('SendBusLocation', args: [{"BusID":choosenBusId,"Longitude":long,"Latitude":lat,"heading":50.0,"headingAccuracy":0.0}]);
    print("result:: $send");
    connection?.invoke("GetListBusMap");

  }

  receiveMessage()async {
    var send = await connection?.send(methodName: "GetListBusMap");
    // print("result receive:: ${send}");
  }
  bool isLocationUpdated = false;

  var location = loc.Location();
  geo.Position? currentPosition;
  double bottomPaddingOfMap = 0;
  late loc.PermissionStatus _permissionGranted;

//get location for all
  Future getLocation() async {
    loc.Location location = loc.Location.instance;

    geo.Position? currentPos;
    loc.PermissionStatus permissionStatus = await location.hasPermission();
    _permissionGranted = permissionStatus;
    if (_permissionGranted != loc.PermissionStatus.granted) {
      final loc.PermissionStatus permissionStatusReqResult =
      await location.requestPermission();

      _permissionGranted = permissionStatusReqResult;
    }

    loc.LocationData loca = await location.getLocation();
    latitudeNew = loca.latitude!;
    longitudeNew = loca.longitude!;
    location.enableBackgroundMode(enable: true,);
    print(" ##@@@@@@## current  location ##@@@@@@@## ${loca.heading} ,, ${loca.headingAccuracy}");
    location.onLocationChanged.listen((LocationData currentLocation)async {
      // Use current location

      print("new location ..lat.. ${currentLocation.latitude}");
      print("new location ..lng.. ${currentLocation.longitude}");
      latitudeOld = latitudeNew;
      longitudeOld =longitudeNew;

      latitudeNew = currentLocation.latitude!;
      longitudeNew = currentLocation.longitude!;

      var firstDistance = getDistanceFromLatLonInKm(  currentLocation.latitude,currentLocation.longitude,latitudeOld  ,longitudeOld );
      var secondDistance = getDistanceFromLatLonInKm(  latitudeNew,longitudeNew,latitudeOld  ,longitudeOld );
      // if(chooseDone){
      //   await sendMessageBus(currentLocation.latitude!, currentLocation.longitude!);
      // }

    });


    BackgroundLocation.startLocationService(distanceFilter: 5);

    BackgroundLocation.getLocationUpdates((location) async {

        isLocationUpdated = true;

            latitudeOld = latitudeNew;
            longitudeOld =longitudeNew;

            latitudeNew = location.latitude!;
            longitudeNew = location.longitude!;


            var firstDistance = getDistanceFromLatLonInKm(  location.latitude,location.longitude,latitudeOld  ,longitudeOld );
            var secondDistance = getDistanceFromLatLonInKm(  latitudeNew,longitudeNew,latitudeOld  ,longitudeOld );
            print("lat new $latitudeNew -- long new $longitudeNew ||| lat Old $latitudeOld -- long old $longitudeOld");
          print("first $firstDistance -- second $secondDistance");
          if(chooseDone){
            await sendMessageBus(location.latitude!, location.longitude!);
          }
          print("......... send location update counter .......");

          isLocationUpdated = false;


      // print("location ....... background update ${location.longitude} - ${location.latitude}");
      //audioPlayerService.audio1Play();
    });
    if (loca.latitude != null) {
      currentPosition = geo.Position(
        latitude: loca.latitude!,
        longitude: loca.longitude!,
        accuracy: loca.accuracy!,
        altitude: loca.altitude!,
        speedAccuracy: loca.speedAccuracy!,
        heading: loca.heading!,
        timestamp: DateTime.now(),
        speed: loca.speed!,
      );

    }

  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getLocation();
    signalRInit();

  }

  /// This is list of city which will pass to the drop down.
  final List<SelectedListItem> _listOfBusses = [];

  /// This is register text field controllers.

  final TextEditingController _cityTextEditingController = TextEditingController();


  @override
  void dispose() {
    super.dispose();
    _cityTextEditingController.dispose();
  }
  /// This is Main Body widget.
  Widget _mainBody() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          AppTextField(
            textEditingController: _cityTextEditingController,
            title: "Buss",
            hint: title,
            isCitySelected: true,
            cities: _listOfBusses,
          ),

          const SizedBox(
            height: 15.0,
          ),

        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        title: Text(widget.title),
      ),
      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:CrossAxisAlignment.center,
          children: <Widget>[
           gotItems == true ? _mainBody():Container(),


            const SizedBox(height: 50,),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: ()async{
                  await sendMessageBus(latitudeNew,longitudeNew);

                }, child: const Text("Send Bus 1")),
                const SizedBox(width: 30,),

                ElevatedButton(onPressed: (){

                  sendMessage();
                }, child: const Text("Send User")),

              ],
            ),
            const SizedBox(height: 50,),
            ElevatedButton(onPressed: (){

              receiveMessage();
            }, child: const Text("Receive Bus")),
          ],


        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}


String title = "Choose Bus";
/// This is Common App textfiled class.
class AppTextField extends StatefulWidget {
  final TextEditingController textEditingController;
  final String title;
  final String hint;
  final bool isCitySelected;
  final List<SelectedListItem>? cities;

  const AppTextField({
    required this.textEditingController,
    required this.title,
    required this.hint,
    required this.isCitySelected,
    this.cities,
    Key? key,
  }) : super(key: key);

  @override
  _AppTextFieldState createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final TextEditingController _searchTextEditingController = TextEditingController();

  /// This is on text changed method which will display on city text field on changed.
  void onTextFieldTap() {
    DropDownState(
      DropDown(
        bottomSheetTitle: const Text(
          "Busses",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20.0,
          ),
        ),
        submitButtonChild: const Text(
          'Done',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        data: widget.cities ?? [],
        selectedItems: (List<dynamic> selectedList)async {
          List<String> list = [];
          for(var item in selectedList) {
            if(item is SelectedListItem) {
              list.add(item.name);
              choosenBusId = item.value!;
              chooseDone =true;
              setState(() {
                title =item.name;

              });

            }
          }
          showSnackBar(list.toString());

        },
       // enableMultipleSelection: true,
      ),
    ).showModal(context);
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title),
        const SizedBox(
          height: 5.0,
        ),
        TextFormField(
          controller: widget.textEditingController,
          cursorColor: Colors.black,
          onTap: widget.isCitySelected
              ? () {
            FocusScope.of(context).unfocus();
            onTextFieldTap();
          }
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black12,
            contentPadding: const EdgeInsets.only(left: 8, bottom: 0, top: 0, right: 15),
            hintText: widget.hint,
            border: const OutlineInputBorder(
              borderSide: BorderSide(
                width: 0,
                style: BorderStyle.none,
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(8.0),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 15.0,
        ),
      ],
    );
  }
}
