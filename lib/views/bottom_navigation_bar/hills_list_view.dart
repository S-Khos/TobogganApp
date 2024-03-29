import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tobogganapp/firestore_helper.dart';
import 'package:tobogganapp/model/hill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bottom_navigation_bar/hill_details.dart';

class HillsListView extends StatefulWidget {
  const HillsListView({Key? key}) : super(key: key);

  @override
  State<HillsListView> createState() => _HillsListViewState();
}

class _HillsListViewState extends State<HillsListView> {
  List<Hill> _hills = [];
  bool _loadedHills = false;
  late LatLng _userLocation;

  @override
  void initState() {
    loadHills();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _loadedHills
        ? ListView.builder(
            itemCount: _hills.length,
            itemBuilder: (BuildContext context, int index) {
              return HillInfoCard(_hills[index], _userLocation);
            })
        : const Center(child: CircularProgressIndicator());
  }

  Future<void> loadHills() async {
    // fetch user location and store it, helps show distance to hill
    var loc = await Geolocator.getLastKnownPosition();

    // fetch the hills and sort by closest distance to user
    List<Hill> hills = await FirestoreHelper.getAllHills();
    hills.sort((a, b) {
      return a
          .distanceFrom(LatLng(loc!.latitude, loc.longitude))
          .compareTo(b.distanceFrom(LatLng(loc.latitude, loc.longitude)));
    });

    setState(() {
      _userLocation = LatLng(loc!.latitude, loc.longitude);
      _loadedHills = true;
      _hills = hills;
    });
  }
}

class HillInfoCard extends StatefulWidget {
  final Hill _hill;
  final LatLng _userLocation;

  const HillInfoCard(this._hill, this._userLocation, {Key? key})
      : super(key: key);

  @override
  State<HillInfoCard> createState() => _HillInfoCardState();
}

class _HillInfoCardState extends State<HillInfoCard> {
  bool isBookmarked = false;

  @override
  void initState() {
    determineBookmarked();
    super.initState();
  }

  determineBookmarked() async {
    bool bookmarked = await FirestoreHelper.isHillBookmarked(
        FirebaseAuth.instance.currentUser!.uid, widget._hill.hillID);
    setState(() {
      isBookmarked = bookmarked;
    });
  }

  toggleBookmark() async {
    // toggle bookmark
    await FirestoreHelper.toggleHillBookmarkFor(
        FirebaseAuth.instance.currentUser!.uid, widget._hill.hillID);

    // present relevant message if depending on whether hill is now bookmarked
    bool bookmarked = await FirestoreHelper.isHillBookmarked(
        FirebaseAuth.instance.currentUser!.uid, widget._hill.hillID);
    String message;
    if (bookmarked) {
      message = "Bookmark added!";
    } else {
      message = "Bookmark removed";
    }

    // show snackbar
    SnackBar snackbar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackbar);

    setState(() {
      isBookmarked = bookmarked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => Hilldetails(widget._hill)));
      },
      child: Card(
        child: Column(
          children: [
            widget._hill.featuredPhoto,
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15),
              child: Column(
                children: [
                  Row(children: [
                    Text(
                      widget._hill.name,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ]),
                  Row(children: [
                    Icon(Icons.star,
                        color: widget._hill.rating.round() >= 1
                            ? Colors.amber
                            : Colors.grey),
                    Icon(Icons.star,
                        color: widget._hill.rating.round() >= 2
                            ? Colors.amber
                            : Colors.grey),
                    Icon(Icons.star,
                        color: widget._hill.rating.round() >= 3
                            ? Colors.amber
                            : Colors.grey),
                    Icon(Icons.star,
                        color: widget._hill.rating.round() >= 4
                            ? Colors.amber
                            : Colors.grey),
                    Icon(Icons.star,
                        color: widget._hill.rating.round() >= 5
                            ? Colors.amber
                            : Colors.grey),
                    const SizedBox(width: 10),
                    Text("(" +
                        (widget._hill.reviews.length == 1
                            ? "${widget._hill.reviews.length} review"
                            : "${widget._hill.reviews.length} reviews") +
                        ")")
                  ]),
                  Row(children: [
                    Text(
                        "${widget._hill.address} ⋅ ${widget._hill.distanceFrom(widget._userLocation)}km",
                        style: const TextStyle(color: Colors.grey)),
                  ]),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () {
                            toggleBookmark();
                          },
                          child: Text(
                              isBookmarked ? "REMOVE BOOKMARK" : "BOOKMARK")),
                      TextButton(
                          onPressed: () async {
                            // launch directions to hill
                            var pos = await Geolocator.getCurrentPosition();
                            String url =
                                "https://www.google.com/maps/dir/?api=1&origin=${pos.latitude},${pos.longitude}&destination=${widget._hill.address}}";
                            await launch(Uri.encodeFull(url));
                          },
                          child: const Text("DIRECTIONS"))
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
