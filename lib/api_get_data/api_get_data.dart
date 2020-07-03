import "dart:async";
import "package:http/http.dart" as http;
import "dart:convert";
import "package:apod_app/api_class_data/aopd_api_class.dart";
import "package:apod_app/api_get_data/api_key.dart";

class ApodAPICallback {
  ApodAPICallback();

  Future<Apod> getData(String date) async {
    String url = "https://api.nasa.gov/planetary/apod?api_key=" +
        nasaApiKey +
        "&hd=true&date=" +
        date;

    var res = await http.get(url);
    var decodedJson = jsonDecode(res.body);

    Apod apodData = new Apod.fromJson(decodedJson);

    return apodData;
  }
}
