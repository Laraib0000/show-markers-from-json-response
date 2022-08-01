import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trigon_application/Constants/colors.dart';

import 'package:trigon_application/Services/stats_services.dart';

import '../Constants/constants.dart';
import '../Constants/lat_lng.dart.dart';

import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart' as myPermission;

import '../Constants/utilities.dart';
import '../Services/api_urls.dart';
import 'EVSDetail_screen.dart';
import 'near_me.dart';

class RouteOption extends StatefulWidget {
  @override
  _RouteOptionState createState() => _RouteOptionState();
}

class _RouteOptionState extends State<RouteOption> {
  GoogleMapController? _controller;

  List<Marker> allMarkers = [];

  late PageController _pageController;
  LatLng closestlatlng = LatLng(0, 0);

  int? prevPage;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};

  EVSStations evsStations = EVSStations();
  int _markerIdCounter = 1;
  myPermission.PermissionStatus? permissionStatus;
  var location = Location();
  late BitmapDescriptor _markerIcon;
  bool _loading = false;

  var nearestDistance = 0;

  @override
  void initState() {
    super.initState();
  }

  double value = 999999;
  double distance = 0.0;
  LatLng latlng = LatLng(0, 0);

  fetchEvsRecord() async {
    // here I hit api and store data in a variable named res.

    if (res.statusCode == 200) {
      var data = jsonDecode(res.body);
      var resData = data["data"];
      if (resData.length > 0) {
        createMarker(resData);
      } else {}

      print("allRecords ${resData.length}");
    } else {
      throw Exception('Failed');
    }
  }

  LocationData? currentLocation;
  void getCurrentLocation() {
    Location location = Location();
    location.getLocation().then((location) {
      currentLocation = location;
      print("location is $currentLocation");
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
        body: Stack(
      children: <Widget>[
        Container(
          height: MediaQuery.of(context).size.height - 50.0,
          width: MediaQuery.of(context).size.width,
          child: GoogleMap(
            mapToolbarEnabled: false,
            initialCameraPosition: const CameraPosition(
                target: LatLng(13.7563, 100.5018), zoom: 8.0),
            markers: Set<Marker>.of(markers.values),
            onMapCreated: mapCreated,
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 10.0),
              child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NearMeScreen(
                                  latlng: closestlatlng,
                                )));
                  },
                  child: Container(
                    height: height * 0.073,
                    width: width * 0.31,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: whiteC.withOpacity(0.76)),
                    child: Center(
                      child: Text(
                        'Nearby Me',
                        style: smallTextW,
                      ),
                    ),
                  )),
            ),
          ],
        ),
      ],
    ));
  }

  void mapCreated(controller) async {
    setState(() {
      _controller = controller;
      fetchEvsRecord();
    });
    await myPermission.Permission.location.request();
    permissionStatus = await myPermission.Permission.location.status;
    if (permissionStatus!.isGranted) {
      final post = await location.getLocation();
      print("this is my location $post");
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(13.736717, 100.523186),
            zoom: 5,
          ),
        ),
      );

      _createMarker(post.latitude!, post.longitude!);
    } else {
      permissionDeniedMethod(
        context,
        "Location",
      );
    }
  }

  moveCamera() {
    _controller!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: coffeeShops[_pageController.page!.toInt()].gps_lat,
        zoom: 14.0,
        bearing: 45.0,
        tilt: 45.0)));
  }

  createMarker(lstZones) async {
    if (lstZones != null && lstZones.length > 0) {
      final post = await location.getLocation();
      print("position is $post");
      for (int x = 0; x < lstZones.length; x++) {
        if (lstZones[x] != null &&
            lstZones[x]["lat"] != null &&
            lstZones[x]["lng"] != null) {
          var _distanceInMeters = Geolocator.distanceBetween(
              double.parse(lstZones[x]["lat"]),
              double.parse(lstZones[x]["lng"]),
              post.latitude!,
              post.longitude!);
          var distanceInKM = _distanceInMeters / 1000;
          print(" distance in Km:  $distanceInKM");

          if (distanceInKM < value) {
            value = distanceInKM;
            closestlatlng = LatLng(double.parse(lstZones[x]["lat"]),
                double.parse(lstZones[x]["lng"]));

            print("values is : $value && x value is: $x && lat is $latlng");
          }
          var dataBytes;

          final Uint8List markerIcon =
              await getBytesFromAsset('assets/images/evs.png', 100);

          _markerIdCounter++;
          final MarkerId markerId = MarkerId(_markerIdCounter.toString());

          double lat, long;
          lat = double.parse(lstZones[x]["lat"]);
          long = double.parse(lstZones[x]["lng"]);

          final Marker marker = Marker(
            markerId: markerId,
            position: LatLng(lat, long),
            icon: BitmapDescriptor.fromBytes(markerIcon),
            infoWindow: InfoWindow(
                title: lstZones[x]["chargerID"],
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => EVSDetailScreen(
                                photo: lstZones[x]["chargerPhoto"],
                                type: lstZones[x]["location"]["textEN"],
                                number: lstZones[x]["number"],
                                status: lstZones[x]["chargerStatus"]["textEN"],
                                description1: lstZones[x]["description"]
                                    ["textEN"],
                                description2: lstZones[x]["description"]
                                    ["textTH"],
                                connector: lstZones[x]["connector"],
                                lat: lstZones[x]["lat"],
                                lng: lstZones[x]["lng"],
                              )));
                }),
          );
          setState(() {
            markers[markerId] = marker;
          });
        }
      }
    } else
      print('no data found');
  }

  Future<BitmapDescriptor> getMarkerIcon(String imagePath, Size size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Radius radius = Radius.circular(size.width / 2);

    final Paint tagPaint = Paint()..color = Colors.blue;
    final double tagWidth = 40.0;

    final Paint shadowPaint = Paint()
      ..color = hexToColor(lightBlueColor).withAlpha(100);
    final double shadowWidth = 15.0;

    final Paint borderPaint = Paint()..color = Colors.white;
    final double borderWidth = 3.0;

    final double imageOffset = shadowWidth + borderWidth;

    canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0.0, 0.0, size.width, size.height),
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        shadowPaint);

    canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(shadowWidth, shadowWidth,
              size.width - (shadowWidth * 2), size.height - (shadowWidth * 2)),
          topLeft: radius,
          topRight: radius,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        borderPaint);

    Rect oval = Rect.fromLTWH(imageOffset, imageOffset,
        size.width - (imageOffset * 2), size.height - (imageOffset * 2));

    canvas.clipPath(Path()..addOval(oval));

    ui.Image image = await getImageFromPath(imagePath);
    paintImage(canvas: canvas, image: image, rect: oval, fit: BoxFit.fitWidth);

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());

    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<ui.Image> getImageFromPath(String imagePath) async {
    File imageFile = File(imagePath);

    Uint8List imageBytes = imageFile.readAsBytesSync();

    final Completer<ui.Image> completer = Completer();

    ui.decodeImageFromList(imageBytes, (ui.Image img) {
      return completer.complete(img);
    });

    return completer.future;
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  _createMarker(double latitude, double longitude) async {
    String markerPath = "assets/images/findevs.png";
    final Uint8List markerIcon = await getBytesFromAsset(markerPath, 130);

    _markerIcon = BitmapDescriptor.fromBytes(markerIcon);

    _markerIdCounter++;
    final MarkerId markerId = MarkerId(_markerIdCounter.toString());

    final Marker marker = Marker(
        markerId: markerId,
        position: LatLng(latitude, longitude),
        icon: _markerIcon,
        onTap: () {});

    print("hello");
    setState(() {
      markers[markerId] = marker;
    });
  }
}
