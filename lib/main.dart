// ignore_for_file: prefer_const_constructors

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'dart:convert'; // For converting process output
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.green,
      ),
      home: const TerminalScreen(),
    );
  }
}

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TerminalScreenState createState() => _TerminalScreenState();
}

class FileViewerScreen extends StatefulWidget {
  final String filePath;

  const FileViewerScreen({super.key, required this.filePath});

  @override
  // ignore: library_private_types_in_public_api
  _FileViewerScreenState createState() => _FileViewerScreenState();
}


class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<String> outputs = ["Welcome to ITerminal!"];
  String currentDirectory = Directory.current.path;
  Color textColor = Colors.green;
  Color backgroundColor = Colors.black;

  final Map<String, Map<String, Color>> themes = {
    "Default": {'text': Colors.green, 'background': Colors.black},
    "White on Blue": {'text': Colors.white, 'background': Colors.blue.shade900},
    "Yellow on Dark": {'text': Colors.yellow, 'background': Colors.grey.shade50},
    "Red on Grey": {'text': Colors.red, 'background': Colors.grey.shade300},
    "Cyan on Navy": {'text': Colors.cyan, 'background': Colors.blueGrey.shade900},
    "Orange on Dark Grey": {'text': Colors.orange, 'background': Colors.grey.shade800},
    "Lime on Dark Blue": {'text': Colors.limeAccent, 'background': Colors.blueGrey.shade800},
  };

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ITerminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsPanel,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: backgroundColor,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: outputs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        outputs[index],
                        style: TextStyle(color: textColor),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: "Type your command here",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  style: TextStyle(color: textColor),
                  onSubmitted: _executeCommand,
                  onTap: () => _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: themes.keys.map((String key) {
              return ListTile(
                leading: const Icon(Icons.palette),
                title: Text(key),
                onTap: () {
                  setState(() {
                    textColor = themes[key]!['text']!;
                    backgroundColor = themes[key]!['background']!;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _executeCommand(String command) {
    if (command.isEmpty) {
      return;
    }
    command.split(';').forEach((part) {
      setState(() {
        outputs.add("> $part");
        _controller.clear();
        outputs.addAll(_processCommand(part.trim().split(' ')));
      });
    });
    Timer(
      const Duration(milliseconds: 100),
      () => _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
    );
    FocusScope.of(context).requestFocus(_focusNode);
  }

 List<String> _processCommand(List<String> segments) {
    var command = segments[0].toLowerCase();
    List<String> response = [];
    switch (command) {
      case 'run':
        if (segments.length > 1) {
          executePythonScript(segments[1]).then((output) {
            setState(() {
              outputs.addAll(output);
            });
          });
        } else {
          response.add("No script specified.");
        }
        break;
      case 'open':
        if (segments.length > 1) {
          response.addAll(handleViewFile(context, segments[1]));
        } else {
          response.add("No file specified.");
        }
        break;
      case 'ls':
        response.addAll(handleLs());
        break;
      case 'cd':
        if (segments.length > 1) {
          response.add(handleCd(segments[1]));
        } else {
          response.add("No directory specified.");
        }
        break;
      case 'pwd':
        response.add("Current directory: $currentDirectory");
        break;
      case 'mkdir':
        if (segments.length > 1) {
          response.add(handleMkdir(segments[1]));
        } else {
          response.add("No directory name specified.");
        }
        break;
      case 'touch':
        if (segments.length > 1) {
          response.add(handleTouch(segments[1]));
        } else {
          response.add("No file name specified.");
        }
        break;
      case 'cat':
        if (segments.length > 1) {
          response.addAll(handleCat(segments[1]));
        } else {
          response.add("No file specified.");
        }
        break;
      case 'rm':
        if (segments.length > 1) {
          response.add(handleRm(segments[1]));
        } else {
          response.add("No file specified.");
        }
        break;
      case 'clear':
        setState(() {
          outputs.clear();
        });
        break;
      case 'exit':
    // For Android, use SystemNavigator.pop() to close the app
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } 
    // For iOS, reset app state or navigate to the initial route
    else if (Platform.isIOS) {
      _resetAppState();
    }
    break;
      case 'help':
        response.addAll([
          "Commands:",
          "ls - List directory contents",
          "cd [dir] - Change directory",
          "pwd - Show current directory",
          "mkdir [dir] - Create a new directory",
          "touch [file] - Create a new file",
          "cat [file] - Display file contents",
          "rm [file] - Remove a file",
          "clear - Clear the screen",
          "exit - Close ITerminal",
          "help - Show this help message",
          "open - open files to view",
        ]);
        break;
      default:
        response.add("Command not recognized.");
        break;
    }
    return response;
  }

  void _resetAppState() {
  // Example of navigating back to the initial route (home screen)
  Navigator.of(context).popUntil((route) => route.isFirst);
  
  // Clear any user data you have stored
  // For example, if you store user data in a singleton or global accessible class.
  // UserData.clear();

  // Reset any state management you are using, such as Provider, Riverpod, Bloc, etc.
  // Example using Provider:
  // context.read<UserDataProvider>().resetUserData();

  // Clear any persistent storage you are using like Shared Preferences or a database
  // SharedPreferences prefs = await SharedPreferences.getInstance();
  // await prefs.clear(); // This will clear all data stored in Shared Preferences

  // If using a database, you might want to delete certain tables or reset them
  // DatabaseProvider.db.resetDatabase(); // Custom function to reset your database

  // If you are using any form of caching, clear it
  // CacheManager.clear();

  // Reset any other services or controllers you might have
  // Example: if you are using a service to keep the user logged in
  // AuthenticationService().logout();

  // If there are any other configurations or app-related settings that should be reset, do so here
  // AppConfig.reset();

  // Set any relevant app state back to its initial conditions
  // AppStateManager.reset();

  // If your app has a login flow, you might want to navigate the user to the login screen
  // This can be a pushReplacement so that the user can't navigate back to the session
  // Navigator.pushReplacementNamed(context, '/login');
}


  List<String> handleViewFile(BuildContext context, String fileName) {
  final filePath = path.join(currentDirectory, fileName);
  if (File(filePath).existsSync()) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FileViewerScreen(filePath: filePath)));
    return [];
  } else {
    return ["Failed to open file '$fileName': File does not exist."];
  }
}


  List<String> handleLs() {
    try {
      return Directory(currentDirectory)
          .listSync()
          .map((item) => path.basename(item.path) + (item.statSync().type == FileSystemEntityType.directory ? '/' : ''))
          .toList();
    } catch (e) {
      return ["Error listing directory: $e"];
    }
  }

  String handleCd(String newPath) {
    final newDir = path.normalize(path.join(currentDirectory, newPath));
    if (Directory(newDir).existsSync()) {
      currentDirectory = newDir;
      return "Changed directory to: $newDir";
    } else {
      return "Directory does not exist.";
    }
  }

  String handleMkdir(String dirName) {
    try {
      Directory(path.join(currentDirectory, dirName)).createSync();
      return "Directory '$dirName' created.";
    } catch (e) {
      return "Failed to create directory '$dirName': $e";
    }
  }

  String handleTouch(String fileName) {
    try {
      File(path.join(currentDirectory, fileName)).createSync();
      return "File '$fileName' created.";
    } catch (e) {
      return "Failed to create file '$fileName': $e";
    }
  }

  List<String> handleCat(String fileName) {
    final file = File(path.join(currentDirectory, fileName));
    try {
      return file.readAsLinesSync();
    } catch (e) {
      return ["Failed to read file '$fileName': $e"];
    }
  }

  String handleRm(String fileName) {
    try {
      final file = File(path.join(currentDirectory, fileName));
      file.deleteSync();
      return "File '$fileName' deleted.";
    } catch (e) {
      return "Failed to delete file '$fileName': $e";
    }
  }

  // Function to execute Python scripts
  Future<List<String>> executePythonScript(String scriptFileName) async {
  final results = <String>[];
  // Join the current directory with the script file name
  final scriptPath = path.join(currentDirectory, scriptFileName);

  // Debug print to check the script path
  if (kDebugMode) {
    print("Attempting to execute script at: $scriptPath");
  }

  final scriptFile = File(scriptPath);
  if (!scriptFile.existsSync()) {
    return ["Script file does not exist: $scriptPath"];
  }

   try {
    // Start the Python process
    final process = await Process.start('python', [scriptPath]);

    // Capture standard output and error streams
    final stdoutStream = process.stdout.transform(utf8.decoder);
    final stderrStream = process.stderr.transform(utf8.decoder);

    // Handle standard output
    await for (var line in stdoutStream) {
      results.add(line);
    }

    // Handle standard error
    await for (var line in stderrStream) {
      results.add(line);
    }

    // Wait for the process to exit
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      results.add("Script exited with error code: $exitCode");
    }
  } catch (e) {
    results.add("Failed to execute script: $e");
  }

  return results;
}

Future<void> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

   @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late String fileContents;
  late TextEditingController textController;
  late FocusNode textFocusNode;

  @override
  void initState() {
    super.initState();
    textFocusNode = FocusNode();
    fileContents = File(widget.filePath).readAsStringSync();
    textController = TextEditingController(text: fileContents);

    // Request focus for the text field when the state is initialized.
    // This will bring up the keyboard for the text field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(textFocusNode);
    });
  }

  @override
  void dispose() {
    textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(widget.filePath)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Read-only highlighted code view
            HighlightView(
              fileContents,
              language: 'dart',
              theme: githubTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
            ),
            // Editable text field with toolbar options for copy and paste
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: textController,
                focusNode: textFocusNode,
                maxLines: null, // Makes it multi-line
                style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Edit File',
                ),
                onChanged: (value) {
                  fileContents = value;
                },
                // ignore: deprecated_member_use
                toolbarOptions: const ToolbarOptions(copy: true, paste: true, selectAll: true, cut: true),
              ),
            ),
            // Add coding helper buttons if needed
            Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Replace these buttons with whatever symbols you need
        _buildSymbolButton('<'),
        _buildSymbolButton('>'),
        _buildSymbolButton('{'),
        _buildSymbolButton('}'),
        _buildSymbolButton('['),
        _buildSymbolButton(']'),
        // ... more symbols as needed ...
      ],
    ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Save the edited content back to file
          File(widget.filePath).writeAsStringSync(textController.text);
          Navigator.pop(context);
        },
        child: const Icon(Icons.save),
      ),
    );
  }

  void insertText(String textToInsert) {
    final text = textController.text;
    final textSelection = textController.selection;
    final newText = text.replaceRange(textSelection.start, textSelection.end, textToInsert);
    textController.text = newText;
    // Set the cursor position at the end of the inserted text
    textController.selection = textSelection.copyWith(
      baseOffset: textSelection.start + textToInsert.length,
      extentOffset: textSelection.start + textToInsert.length,
    );
  }

  Widget _buildSymbolButton(String symbol) {
    return ElevatedButton(
      onPressed: () => insertText(symbol),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(44, 44), // increases touch target
        padding: EdgeInsets.zero,
      ),
      child: Text(symbol),
    );
  }
}
