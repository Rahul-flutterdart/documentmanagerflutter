import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:audioplayers/audioplayers.dart' as ap;
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
  bool _isPlaying = false;
  DateTime? _expiryDate;
  fs.FlutterSoundRecorder? _audioRecorder;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  Duration _recordingDuration = Duration.zero;
  late StreamSubscription _recordingSubscription;

  @override
  void initState() {
    super.initState();
    _audioRecorder = fs.FlutterSoundRecorder();
    _checkPermissions();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == ap.PlayerState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioRecorder?.closeRecorder();
    _audioPlayer.dispose();
    _recordingSubscription.cancel();
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

      _recordingSubscription = _audioRecorder!.onProgress!.listen((event) {
        setState(() {
          _recordingDuration = event.duration;
        });
      });

      setState(() {
        _isRecording = true;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Recording Started'),
          content: Text('Audio recording has started.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stopRecorder();
      await _audioRecorder!.closeRecorder();
      _recordingSubscription.cancel();

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Recording Stopped'),
          content: Text('Audio recording has stopped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _recordAudio() async {
    try {
      if (_isRecording) {
        await _stopRecording();
        print('Audio recording stopped. Saved to crazzyyy rahul: $_audioPath');
      } else {
        if (_attachmentType.isNotEmpty) {
          setState(() {
            _clearAttachment();
          });
        }
        await _startRecording();
        print('Audio recording started. Saving to  crazzyy rahul: $_audioPath');
      }
    } catch (e) {
      print('Error recording audio: $e');
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      try {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play(ap.DeviceFileSource(_audioPath!));
        }
        setState(() {
          _isPlaying = !_isPlaying;
        });
        print('Playing audio from crazzyy rahul: $_audioPath');
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
      if (_attachmentType.isNotEmpty) {
        setState(() {
          _clearAttachment();
        });
      }
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
      if (_attachmentType.isNotEmpty) {
        setState(() {
          _clearAttachment();
        });
      }
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
      if (_attachmentType.isNotEmpty) {
        setState(() {
          _clearAttachment();
        });
      }
      setState(() {
        _videoController = VideoPlayerController.file(File(pickedFile.path))
          ..initialize().then((_) {
            setState(() {});
          });
        _attachmentType = 'Video';
      });
    }
  }

  void _clearAttachment() {
    _image = null;
    _file = null;
    _videoController?.dispose();
    _videoController = null;
    _audioPath = null;
    _attachmentType = '';
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
      createdOn: DateTime.now(),
      expiryDate: _expiryDate,
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
      return _audioPath;
    }
    return null;
  }

  Future<void> _selectExpiryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _expiryDate) {
      setState(() {
        _expiryDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Document'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              SizedBox(height: 16.0),

              // Expiry Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Expiry Date: ${_expiryDate != null ? '${_expiryDate!.toLocal().toString().split(' ')[0]}' : 'None'}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectExpiryDate,
                    icon: Icon(Icons.calendar_today),
                    label: Text('Select Date'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),

              Text(
                'Attach a document:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.0),
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: [
                  ElevatedButton.icon(
                    onPressed: _selectFile,
                    icon: Icon(Icons.attach_file),
                    label: Text('Attach File'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _captureImage,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Capture Image'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _recordVideo,
                    icon: Icon(Icons.videocam),
                    label: Text('Record Video'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _recordAudio,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Stop Recording' : 'Record Audio'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),

              if (_isRecording)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recording.....in progress',
                      style: TextStyle(color: Colors.red),
                    ),
                    SizedBox(height: 8.0),
                  ],
                ),


              if (_image != null) ...[
                SizedBox(height: 16.0),
                Text('Image Preview:'),
                SizedBox(height: 8.0),
                Image.file(File(_image!.path), height: 200, fit: BoxFit.cover),
              ],

              // Display PDF or File Info
              if (_file != null && _file!.extension == 'pdf') ...[
                SizedBox(height: 16.0),
                Text('PDF Attached: ${_file!.name}'),
              ] else if (_file != null) ...[
                SizedBox(height: 16.0),
                Text('File Attached: ${_file!.name}'),
              ],

              if (_audioPath != null) ...[
                ElevatedButton(
                  onPressed: _playAudio,
                  child: Text(_isPlaying ?  'Pause Audio':'Play Audio'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ],
              if (_videoController != null && _videoController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              SizedBox(height: 24.0),
              Center(
                child: ElevatedButton(
                  onPressed: _saveDocument,
                  child: Text('Save Document'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(horizontal: 100, vertical: 20),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}
