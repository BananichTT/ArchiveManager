enum ReportType {
  x5,
  crystal,
}

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.x5:
        return 'Отчет X5';
      case ReportType.crystal:
        return 'Отчет Кристалл';
    }
  }
}
