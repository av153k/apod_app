import 'package:apod_app/api_class_data/aopd_api_class.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

//for downloading files

// ignore: missing_return
Widget getContainer(Apod _apodSnap, BuildContext context) {
  if (_apodSnap.mediaType == "image") {
    return Container(
      padding: EdgeInsets.all(10),
      child: Image.network(
        _apodSnap.url,
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes
                  : null,
            ),
          );
        },
      ),
    );
  } else if (_apodSnap.mediaType == "video") {
    YoutubePlayerController _controller = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(_apodSnap.url),
      flags: YoutubePlayerFlags(
        autoPlay: false,
        controlsVisibleAtStart: false,
        mute: true,
        hideThumbnail: false,
        hideControls: false,
        loop: false,
      ),
    );
    return Container(
      padding: EdgeInsets.all(10),
      child: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.amber,
        ),
        builder: (context, player) {
          return Column(
            children: <Widget>[
              player,
            ],
          );
        },
      ),
    );
  }
}
