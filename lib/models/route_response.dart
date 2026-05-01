import 'package:latlong2/latlong.dart';

class RouteResponse {
  final int activeStudents;
  final String busId;
  final String college;
  final String createdAt;
  final String from;
  final String routeNumber;
  final String status;
  final List<Stop> stops;
  final int students;
  final String to;
  final String updatedAt;

  RouteResponse({
    required this.activeStudents,
    required this.busId,
    required this.college,
    required this.createdAt,
    required this.from,
    required this.routeNumber,
    required this.status,
    required this.stops,
    required this.students,
    required this.to,
    required this.updatedAt,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      activeStudents: json['activeStudents'] ?? 0,
      busId: json['busId'] ?? '',
      college: json['college'] ?? '',
      createdAt: json['createdAt'] ?? '',
      from: json['from'] ?? '',
      routeNumber: json['routeNumber'] ?? '',
      status: json['status'] ?? '',
      stops: (json['stops'] as List? ?? [])
          .map((i) => Stop.fromJson(i))
          .toList(),
      students: json['students'] ?? 0,
      to: json['to'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeStudents': activeStudents,
      'busId': busId,
      'college': college,
      'createdAt': createdAt,
      'from': from,
      'routeNumber': routeNumber,
      'status': status,
      'stops': stops.map((i) => i.toJson()).toList(),
      'students': students,
      'to': to,
      'updatedAt': updatedAt,
    };
  }
}

class Stop {
  final List<double> coordinates;
  final String name;
  final int students;
  final String time;

  Stop({
    required this.coordinates,
    required this.name,
    required this.students,
    required this.time,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      coordinates: (json['coordinates'] as List? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      name: json['name'] ?? '',
      students: json['students'] ?? 0,
      time: json['time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coordinates': coordinates,
      'name': name,
      'students': students,
      'time': time,
    };
  }

  LatLng get position => LatLng(coordinates[0], coordinates[1]);
}
