import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';  // For recording
import 'package:audioplayers/audioplayers.dart';    // For playback

import 'offline_data/database_helper.dart';
import 'offline_data/model_class.dart';

class AddScreen extends StatefulWidget {
  final VoidCallback onDocumentAdded;

  const AddScreen({Key? key, required this.onDocumentAdded}) : super(key: key);

  @override
  _AddScreenState createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  XFile? _image;
  PlatformFile? _file;
  VideoPlayerController? _videoController;
  String _attachmentType = '';
  String? _audioPath;
  bool _isRecording = false;

  FlutterSoundRecorder? _audioRecorder; // Audio recorder object
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player object

  @override
  void initState() {
    super.initState();
    _audioRecorder = FlutterSoundRecorder();
    _checkPermissions();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioRecorder?.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _audioPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder!.openRecorder();
      await _audioRecorder!.startRecorder(toFile: _audioPath);

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stopRecorder();
      await _audioRecorder!.closeRecorder();

      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _recordAudio() async {
    try {
      if (_isRecording) {
        // Stop recording
        await _stopRecording();
        setState(() {
          _isRecording = false;
        });
        print('Audio recording stopped. Saved to: $_audioPath');
      } else {
        // Start recording
        await _startRecording();
        setState(() {
          _isRecording = true;
          _attachmentType = 'Audio';
        });
        print('Audio recording started. Saving to: $_audioPath');
      }
    } catch (e) {
      print('Error recording audio: $e');
    }
  }

  // Future<void> _startRecording() async {
  //   try {
  //     final tempDir = await getTemporaryDirectory();
  //     _audioPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
  //
  //     await _audioRecorder!.openRecorder();
  //     await _audioRecorder!.startRecorder(toFile: _audioPath);
  //
  //     setState(() {
  //       _isRecording = true;
  //     });
  //   } catch (e) {
  //     print('Error starting recording: $e');
  //   }
  // }
  //
  // Future<void> _stopRecording() async {
  //   try {
  //     await _audioRecorder!.stopRecorder();
  //     await _audioRecorder!.closeRecorder();
  //
  //     setState(() {
  //       _isRecording = false;
  //     });
  //
  //     if (_audioPath != null && File(_audioPath!).existsSync()) {
  //       print('Recording stopped, file exists at: $_audioPath');
  //     } else {
  //       print('Recording stopped, but no file found at: $_audioPath');
  //     }
  //   } catch (e) {
  //     print('Error stopping recording: $e');
  //   }
  // }



  Future<void> _playAudio() async {
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      try {
        await _audioPlayer.play(DeviceFileSource(_audioPath!));
        print('Playing audio from: $_audioPath');
      } catch (e) {
        print('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio')),
        );
      }
    } else {
      print('No audio file found.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No audio file to play')),
      );
    }
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _file = result.files.first;
        _attachmentType = _getFileType(_file!.extension!);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file selected')),
      );
    }
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _attachmentType = 'Image';
      });
    }
  }

  Future<void> _recordVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _videoController = VideoPlayerController.file(File(pickedFile.path))
          ..initialize().then((_) {
            setState(() {});
          });
        _attachmentType = 'Video';
      });
    }
  }

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF';
      case 'xlsx':
      case 'xls':
        return 'Excel';
      default:
        return 'Unknown';
    }
  }

  Future<void> _saveDocument() async {
    final title = _titleController.text;
    final description = _descriptionController.text;

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and Description are mandatory')),
      );
      return;
    }

    if (_attachmentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a file to attach or record audio')),
      );
      return;
    }

    Document newDocument = Document(
      title: title,
      description: description,
      fileType: _attachmentType,
      filePath: _getFilePath()!,
      expiryDate: DateTime.now(),
    );

    await DatabaseHelper.instance.insertDocument(newDocument);
    widget.onDocumentAdded();
    Navigator.pop(context, true);
  }

  String? _getFilePath() {
    if (_file != null) {
      return _file!.path;
    } else if (_image != null) {
      return _image!.path;
    } else if (_videoController != null && _videoController!.value.isInitialized) {
      return _videoController!.dataSource;
    } else if (_audioPath != null) {
      return _audioPath;  // Return the audio path if available
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Document'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveDocument,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.0),
              Text(
                'Attach a document:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectFile,
                      icon: Icon(Icons.attach_file),
                      label: Text('Attach File'),
                    ),
                  ),
                  SizedBox(width: 16.0),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _captureImage,
                      icon: Icon(Icons.camera_alt),
                      label: Text('Capture Image'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recordVideo,
                      icon: Icon(Icons.videocam),
                      label: Text('Record Video'),
                    ),
                  ),
                  SizedBox(width: 16.0),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recordAudio,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Stop Recording' : 'Record Audio'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),

              // Display Recording Indicator
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Recording...',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),

              // Show attached image
              if (_attachmentType == 'Image' && _image != null)
                Image.file(File(_image!.path), height: 200, fit: BoxFit.cover),

              // Show attached video
              if (_attachmentType == 'Video' && _videoController != null)
                _videoController!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
                    : CircularProgressIndicator(),

              // Show attached file (PDF/Excel)
              if (_attachmentType == 'PDF' || _attachmentType == 'Excel')
                Column(
                  children: [
                    Text('Attached file: ${_file!.name}'),
                    SizedBox(height: 8.0),
                    ElevatedButton.icon(
                      onPressed: () {
                        OpenFile.open(_file!.path);
                      },
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text('View File'),
                    ),
                  ],
                ),

              // Show recorded audio
              if (_audioPath != null)
                Column(
                  children: [
                    Text('Recorded Audio:'),
                    ElevatedButton.icon(
                      onPressed: _playAudio,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Play Audio'),
                    ),
                  ],
                ),

              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _saveDocument,
                  icon: Icon(Icons.save),
                  label: Text('Save Document'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
