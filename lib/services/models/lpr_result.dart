class LPRResult {
  final List<double> boxConfs;
  final List<List<double>> boxesXyxy;
  final List<List<double>> normalizedBoxesXyxy;
  final List<String> plateNumbers;

  LPRResult({
    required this.boxConfs,
    required this.boxesXyxy,
    required this.normalizedBoxesXyxy,
    required this.plateNumbers,
  });

  factory LPRResult.fromJson(Map<String, dynamic> json) {
    return LPRResult(
      boxConfs: List<double>.from(json['box_confs']),
      boxesXyxy: (json['boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      normalizedBoxesXyxy: (json['normalized_boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      plateNumbers: List<String>.from(json['plate_numbers']),
    );
  }
}
