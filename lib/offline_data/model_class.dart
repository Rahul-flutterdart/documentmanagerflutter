class Document {
  final int? id;
  final String title;
  final String description;
  final DateTime createdOn; // Updated field
  final DateTime? expiryDate; // New optional field
  final String filePath;
  final String? fileType; // Optional, to store the type of the file

  Document({
    this.id,
    required this.title,
    required this.description,
    required this.createdOn, // Updated constructor
    this.expiryDate,
    required this.filePath,
    this.fileType,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'created_on': createdOn.toIso8601String(),
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
      createdOn: DateTime.parse(map['created_on']),
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'])
          : null,
      filePath: map['file_path'],
      fileType: map['file_type'],
    );
  }
}
