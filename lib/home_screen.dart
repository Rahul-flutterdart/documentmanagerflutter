import 'package:flutter/material.dart';
import 'detailsScreen.dart';
import 'add_screen.dart';
import 'offline_data/database_helper.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> documents;

  @override
  void initState() {
    super.initState();
    _refreshDocuments();
  }

  void _refreshDocuments() {
    setState(() {
      documents = DatabaseHelper.instance.queryAllRows();
    });
  }

  // Format date to a readable string
  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'No Expiry Date';
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat.yMMMd().format(parsedDate);
  }

  // Determine document type icon
  IconData _getDocumentIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Check if document has an expiry date and it's expired
  bool _isExpired(String? expiryDate) {
    if (expiryDate == null || expiryDate.isEmpty) return false;
    DateTime expiry = DateTime.parse(expiryDate);
    return expiry.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Manager'),
        backgroundColor: Colors.deepPurple,
        elevation: 4.0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: documents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No Documents Found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(16.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final isExpired = _isExpired(doc['expiry_date']);
              return Card(
                elevation: 5.0,
                margin: EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16.0),
                  title: Text(
                    doc['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.red : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.0),
                      Text(
                        'Type: ${doc['file_type']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        'Created On: ${_formatDate(doc['expiry_date'])}',
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    _getDocumentIcon(doc['file_type']),
                    color: Colors.deepPurple,
                    size: 30.0,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsScreen(
                          docId: doc['_id'],
                          onDelete: _refreshDocuments,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddScreen(onDocumentAdded: _refreshDocuments),
            ),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}
