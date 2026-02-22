import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dart_nbt/dart_nbt.dart';

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
      // Pick a file. withData: true is crucial for Flutter Web to get the bytes
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true, 
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        
        // Parse the NBT data (dart_nbt auto-detects GZIP/ZLIB compression)
        final parsedNbt = Nbt().read(bytes); 
        
        setState(() {
          rootTag = parsedNbt;
          fileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing NBT: $e')),
      );
    } finally {
      setState(() => isLoading = false);
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
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : pickAndParseFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Open NBT File (.dat, .nbt)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
          if (isLoading) const CircularProgressIndicator(),
          Expanded(
            child: rootTag == null
                ? const Center(child: Text('Upload a file to begin.'))
                : NbtTreeView(tag: rootTag!),
          ),
        ],
      ),
    );
  }
}

/// A recursive widget that visually builds the NBT tree structure
class NbtTreeView extends StatelessWidget {
  final dynamic tag;

  const NbtTreeView({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    // Determine tag name and value safely
    final String name = _getTagName(tag);
    final dynamic value = _getTagValue(tag);
    final String typeName = tag.runtimeType.toString().replaceAll('Nbt', '');

    // If the value is a list (like in NbtCompound or NbtList), it has children
    if (value is List) {
      return ExpansionTile(
        initiallyExpanded: name == 'root' || name.isEmpty,
        leading: Icon(_getIconForType(typeName), color: Colors.tealAccent),
        title: Text(name.isEmpty ? '(Unnamed Compound)' : name),
        subtitle: Text('$typeName [${value.length} items]'),
        children: value.map((childTag) => Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: NbtTreeView(tag: childTag),
        )).toList(),
      );
    } 
    
    // Otherwise, it's a leaf node (a specific value)
    return ListTile(
      leading: Icon(_getIconForType(typeName), color: Colors.grey),
      title: Text(name.isEmpty ? '(Unnamed)' : name),
      subtitle: Text(value.toString()),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 20),
        onPressed: () {
          // TODO: Implement the editing logic and value overwriting here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Editing coming soon!')),
          );
        },
      ),
    );
  }

  String _getTagName(dynamic tag) {
    try {
      return tag.name ?? '';
    } catch (_) {
      return '';
    }
  }

  dynamic _getTagValue(dynamic tag) {
    try {
      return tag.value;
    } catch (_) {
      return tag.toString();
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Compound': return Icons.folder_open;
      case 'List': return Icons.list;
      case 'String': return Icons.text_fields;
      case 'Int': 
      case 'Short': 
      case 'Long': return Icons.numbers;
      case 'Float': 
      case 'Double': return Icons.data_array;
      case 'ByteArray': 
      case 'IntArray': 
      case 'LongArray': return Icons.memory;
      default: return Icons.insert_drive_file;
    }
  }
}