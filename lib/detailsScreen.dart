import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'offline_data/database_helper.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart'; // Added for audio playback

class DetailsScreen extends StatefulWidget {
  final int docId;
  final VoidCallback onDelete;

  DetailsScreen({required this.docId, required this.onDelete});

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late Future<Map<String, dynamic>> _documentFuture;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoError = false;
  bool _isVideoLoading = true;
  bool _isPlaying = false;

  AudioPlayer _audioPlayer = AudioPlayer(); // For audio playback
  bool _isAudioPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _documentFuture = _fetchDocument();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });

    // Listen to audio duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _audioDuration = newDuration;
      });
    });

    // Listen to audio position updates
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _audioPosition = newPosition;
      });
    });
  }

  Future<Map<String, dynamic>> _fetchDocument() async {
    final dbHelper = DatabaseHelper.instance;
    final result = await dbHelper.queryAllRows();
    final document = result.firstWhere((element) => element['_id'] == widget.docId);

    if (document['file_type'] == 'Video') {
      String cleanedFilePath = document['file_path'].replaceFirst('file://', '');
      File videoFile = File(cleanedFilePath);

      if (await videoFile.exists()) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          String newPath = path.join(directory.path, path.basename(cleanedFilePath));
          File newFile = await videoFile.copy(newPath);

          _videoPlayerController = VideoPlayerController.file(newFile)
            ..initialize().then((_) {
              setState(() {});
            }).catchError((error) {
              setState(() {
                _isVideoError = true;
                _isVideoLoading = false;
              });
            });

        } catch (e) {
          print('Error handling video file: $e');
          setState(() {
            _isVideoError = true;
            _isVideoLoading = false;
          });
        }
      } else {
        print('File does not exist at path: $cleanedFilePath');
        setState(() {
          _isVideoError = true;
          _isVideoLoading = false;
        });
      }
    }

    return document;
  }

  Future<void> _playAudio(String filePath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  void _deleteDocument() async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.delete(widget.docId);
    widget.onDelete(); // Notify HomeScreen to refresh the document list
    Navigator.pop(context); // Go back after deleting the document
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _audioPlayer.dispose(); // Dispose of the audio player
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Document'),
                  content: Text('Are you sure you want to delete this document?'),
                  actions: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      child: Text('Delete'),
                      onPressed: () {
                        _deleteDocument();
                        Navigator.pop(context); // Close the dialog after deletion
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _documentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No Document Found'));
          }

          final document = snapshot.data!;
          final filePath = document['file_path'];
          final fileType = document['file_type']?.toString().trim(); // Ensure no leading/trailing spaces

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView( // Make the screen scrollable for smaller devices
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    document['title'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    document['description'],
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 16),
                  if (document['expiry_date'] != null)
                    Text(
                      'Expiry Date: ${document['expiry_date']}',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  SizedBox(height: 24),

                  // Display based on file type
                  if (fileType == 'Image') ...[
                    Image.file(File(filePath)),
                  ] else if (fileType == 'PDF') ...[
                    Container(
                      height: 400,
                      child: PDFView(filePath: filePath),
                    ),
                  ] else if (fileType == 'Video') ...[
                    _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                        ? AspectRatio(
                      aspectRatio: _videoPlayerController!.value.aspectRatio,
                      child: VideoPlayer(_videoPlayerController!),
                    )
                        : Center(child: CircularProgressIndicator()),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_videoPlayerController!.value.isPlaying) {
                                _videoPlayerController?.pause();
                              } else {
                                _videoPlayerController?.play();
                              }
                            });
                          },
                          child: Text(_videoPlayerController!.value.isPlaying ? 'Pause' : 'Play'),
                        ),
                      ],
                    ),
                  ] else if (fileType == 'Audio') ...[
                    Column(
                      children: [
                        Text(
                          'Audio File',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),

                        // Audio Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_isAudioPlaying) {
                                  _pauseAudio();
                                } else {
                                  _playAudio(filePath);
                                }
                              },
                              icon: Icon(_isAudioPlaying ? Icons.pause : Icons.play_arrow),
                              label: Text(_isAudioPlaying ? 'Pause Audio' : 'Play Audio'),
                            ),
                          ],
                        ),

                        // Display duration and current playback position
                        if (_audioDuration != Duration.zero) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Duration: ${_audioDuration.inMinutes}:${(_audioDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Current Position: ${_audioPosition.inMinutes}:${(_audioPosition.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    Text('Unsupported file type: $fileType'),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
