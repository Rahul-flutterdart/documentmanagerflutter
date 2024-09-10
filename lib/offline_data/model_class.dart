class Document {
  final int? id;
  final String title;
  final String description;
  final DateTime? expiryDate;
  final String filePath;
  final String? fileType; // Optional, to store the type of the file

  Document({
    this.id,
    required this.title,
    required this.description,
    this.expiryDate,
    required this.filePath,
    this.fileType,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'expiry_date': expiryDate?.toIso8601String(),
      'file_path': filePath,
      'file_type': fileType,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['_id'],
      title: map['title'],
      description: map['description'],
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'])
          : null,
      filePath: map['file_path'],
      fileType: map['file_type'],
    );
  }
}
