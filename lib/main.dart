import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_nbt/dart_nbt.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html; // Used for downloading the file on the web

void main() {
  runApp(const NbtEditorApp());
}

class NbtEditorApp extends StatelessWidget {
  const NbtEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NBT Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const NbtEditorHome(),
    );
  }
}

class NbtEditorHome extends StatefulWidget {
  const NbtEditorHome({super.key});

  @override
  State<NbtEditorHome> createState() => _NbtEditorHomeState();
}

class _NbtEditorHomeState extends State<NbtEditorHome> {
  NbtCompound? rootTag;
  bool isLoading = false;
  String? fileName;

  Future<void> pickAndParseFile() async {
    setState(() => isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final parsedNbt = Nbt().read(bytes);

        setState(() {
          rootTag = parsedNbt;
          fileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing NBT: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void downloadModifiedFile() {
    if (rootTag == null || fileName == null) return;

    try {
      // 1. Convert the modified NBT Tree back into binary bytes
      // We use GZIP compression as it's the standard for Minecraft level.dat
      final bytes = Nbt().write(rootTag!, compression: NbtCompression.gzip);

      // 2. Trigger the browser download
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "modified_$fileName")
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web NBT Editor'),
        actions: [
          if (fileName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(child: Text('Loaded: $fileName')),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : pickAndParseFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Open NBT File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                const SizedBox(width: 16),
                // New Save Button
                if (rootTag != null)
                  ElevatedButton.icon(
                    onPressed: downloadModifiedFile,
                    icon: const Icon(Icons.download),
                    label: const Text('Save & Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
              ],
            ),
          ),
          if (isLoading) const CircularProgressIndicator(),
          Expanded(
            child: rootTag == null
                ? const Center(child: Text('Upload a file to begin.'))
                : SingleChildScrollView(
                    child: NbtTreeView(
                      tag: rootTag!, 
                      onTagEdited: () => setState(() {}),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class NbtTreeView extends StatelessWidget {
  final dynamic tag;
  final VoidCallback onTagEdited;

  const NbtTreeView({
    super.key, 
    required this.tag, 
    required this.onTagEdited,
  });

  @override
  Widget build(BuildContext context) {
    final String name = _getTagName(tag);
    final dynamic value = _getTagValue(tag);
    final String typeName = tag.runtimeType.toString().replaceAll('Nbt', '');

    if (value is List) {
      return ExpansionTile(
        initiallyExpanded: name == 'root' || name.isEmpty,
        leading: Icon(_getIconForType(typeName), color: Colors.tealAccent),
        title: Text(name.isEmpty ? '(Unnamed Compound)' : name),
        subtitle: Text('$typeName [${value.length} items]'),
        children: value.map((childTag) => Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: NbtTreeView(tag: childTag, onTagEdited: onTagEdited),
        )).toList(),
      );
    } 
    
    return ListTile(
      leading: Icon(_getIconForType(typeName), color: Colors.grey),
      title: Text(name.isEmpty ? '(Unnamed)' : name),
      subtitle: Text(value.toString()),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () => _showEditDialog(context, name, value, typeName),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String name, dynamic currentValue, String typeName) {
    final TextEditingController controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $name ($typeName)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateTagValue(controller.text, typeName);
                onTagEdited(); // Refresh UI
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateTagValue(String newValue, String typeName) {
    try {
      // Parse the string back into the correct data type based on the NBT type
      switch (typeName) {
        case 'String':
          tag.value = newValue;
          break;
        case 'Byte':
        case 'Short':
        case 'Int':
        case 'Long':
          tag.value = int.parse(newValue);
          break;
        case 'Float':
        case 'Double':
          tag.value = double.parse(newValue);
          break;
        // Arrays (Byte/Int/Long arrays) require more complex parsing, skipped for MVP brevity
      }
    } catch (e) {
      debugPrint("Failed to parse $newValue into $typeName");
    }
  }

  String _getTagName(dynamic tag) {
    try { return tag.name ?? ''; } catch (_) { return ''; }
  }

  dynamic _getTagValue(dynamic tag) {
    try { return tag.value; } catch (_) { return tag.toString(); }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Compound': return Icons.folder_open;
      case 'List': return Icons.list;
      case 'String': return Icons.text_fields;
      case 'Int': case 'Short': case 'Long': case 'Byte': return Icons.numbers;
      case 'Float': case 'Double': return Icons.data_array;
      case 'ByteArray': case 'IntArray': case 'LongArray': return Icons.memory;
      default: return Icons.insert_drive_file;
    }
  }
}