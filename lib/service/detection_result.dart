class DetectionResult {
  final List<double> boxConfs;
  final List<List<double>> boxesXyxy;
  final List<List<double>> normalizedBoxesXyxy;
  final List<String> plate_numbers;

  DetectionResult({
    required this.boxConfs,
    required this.boxesXyxy,
    required this.normalizedBoxesXyxy,
    required this.plate_numbers,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      boxConfs: List<double>.from(json['box_confs']),
      boxesXyxy: (json['boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      normalizedBoxesXyxy: (json['normalized_boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      plate_numbers: List<String>.from(json['plate_numbers']),
    );
  }
}
