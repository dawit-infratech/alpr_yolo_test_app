class DetectionResult {
  final List<String> names;
  final List<int> labels;
  final List<double> boxConfs;
  final List<List<double>> boxesXyxy;
  final List<List<double>> nBoxesXyxy;
  final List<String> ocrTexts;
  final List<double> ocrConfs;

  DetectionResult({
    required this.names,
    required this.labels,
    required this.boxConfs,
    required this.boxesXyxy,
    required this.nBoxesXyxy,
    required this.ocrTexts,
    required this.ocrConfs,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      names: Map<String, String>.from(json['names']).values.toList(),
      labels: List<int>.from(json['labels']),
      boxConfs: List<double>.from(json['box_confs']),
      boxesXyxy: (json['boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      nBoxesXyxy: (json['n_boxes_xyxy'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      ocrTexts: List<String>.from(json['ocr_texts']),
      ocrConfs: List<double>.from(json['ocr_confs']),
    );
  }
}
