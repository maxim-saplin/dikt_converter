// @dart=2.9

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/benchmark.dart';

const filePath =
    '/private/var/user/Dropbox/Projects/dikt_misc/dic/dictionaries2/1/RuEnUniversal.json'; //'./En-En-WordNet3-00.json';
const outputExtension = 'dikt';

void main(List<String> arguments) async {
  //bundleJson(filePath);

  stdout.writeln('Welcome to Dikt Converter\n');
  if (arguments.contains('-?') ||
      arguments.contains('-h') ||
      arguments.contains('-help') ||
      arguments.isEmpty) {
    stdout.writeln('To convert a files to dikt format (text JSON and compressed binary DIKT ' +
        'pass folder path with source dictionary files (e.g. with *.dsl.dz) ' +
        'and wait for the converted files to appear in "/_output" folder ' +
        'which will be created inside the source folder.\n' +
        'Source directory is searched recursively. Files that can\'t be processed by pyglossary are ignored.\n' +
        'For each source file thre output files are created:\n' +
        ' - *.JSON - text file containing key/value pairs with key being word and value being article\n' +
        ' - *.DIKT - compressed binary version of JSON which is a compact version of JSON dictionary\n' +
        ' - *.DIKT.TXT - statisitcs related to DIKT file (number of words, size in bytes)\n' +
        '\npyglossary is used to convert source dictionaries to JSON. ' +
        'pyglossary must be located in the same folder as converter folder, e.g:\n' +
        ' - /home/pyglossary\n' +
        ' - /home/dikt_converter/main.dart\n' +
        'python3 must be installed and available from command line.' +
        '\n\nPass "-test" argument to run compression algorythms efficiency benchmark');
    return;
  }
  if (arguments.contains('-test')) {
    stdout.writeln('Running algo benchmark... \n\n');
    testOnFile();
    return;
  }

  var py = File(FileSystemEntity.parentOf(Directory('').absolute.path) +
      '/pyglossary/main.py');

  stdout.writeln(FileSystemEntity.parentOf(Directory('').absolute.path));

  if (!py.existsSync()) {
    stdout.writeln(
        'ERROR, pyglossary entry point not found "${py.absolute.path}"');
    return;
  }

  var d = Directory(arguments[0]);

  if (!d.existsSync()) {
    stdout.writeln('ERROR, directory "${d.absolute.path}" not found');
    return;
  }

  var output = Directory(d.absolute.path + '/_output');

  if (output.existsSync()) {
    stdout.writeln('Clearing /_output folder');
    output.deleteSync(recursive: true);
  }

  output.createSync();

  var files = d.listSync(recursive: true).where((e) =>
      e is File && !e.path.contains('.DS_Store') && !e.path.contains('~'));

  if (files.isEmpty) {
    stdout.writeln('ERROR, no files fouind in directory "${d.absolute.path}"');
    return;
  }

  stdout.writeln(
      'Processing ${files.length} files in "${d.absolute.path}"... \n');

  int done = 0;
  int skipped = 0;

  for (var f in files) {
    stdout.write(f.path);
    stdout.write(' /JSON...');

    var outputJson =
        output.absolute.path + '/' + f.path.split('/').last + '.json';

    var res = Process.runSync(
        'python3', [py.absolute.path, f.absolute.path, outputJson]);
    if (res.exitCode != 0) {
      stdout.writeln(' - Skipping file, pyglossary error');
      stdout.writeln(res.stderr);
      skipped++;
    } else {
      done++;
      stdout.write('done. /DIKT...');

      var outputDikt =
          output.absolute.path + '/' + f.path.split('/').last + '.dikt';
      var outputInfo =
          output.absolute.path + '/' + f.path.split('/').last + '.dikt.txt';

      await bundleJson(outputJson, outputDikt, outputInfo);
      stdout.writeln('done.');
    }
  }

  stdout.writeln(
      '\nConversion complete. Files converted: ${done}, skipped: ${skipped}');
}

void bundleJson(String fileName, String outputFileName,
    [String infoFile, bool verify = false, bool verbose = false]) async {
  var input = File(fileName);
  var output = File(outputFileName); //= File(fileName + '.' + outputExtension);
  var jsonString = await input.readAsString();
  Map mm = json.decode(jsonString);
  var m = mm.cast<String, String>();
  var comp = zlib(m, 6, verbose);

  if (verbose) print('Writing ${m.length} entries to ${output.path}');
  await output.create();
  var raf = await output.open(mode: FileMode.write);

  var bd = ByteData(4);
  bd.setInt32(0, m.length);
  raf.writeFromSync(bd.buffer.asUint8List());

  for (var e in comp.entries) {
    var bytes = utf8.encode(e.key);
    bd = ByteData(4);
    bd.setInt32(0, bytes.length);
    raf.writeFromSync(bd.buffer.asUint8List());
    raf.writeFromSync(bytes);

    bd = ByteData(4);
    bd.setInt32(0, e.value.length);
    raf.writeFromSync(bd.buffer.asUint8List());
    raf.writeFromSync(e.value);
  }
  raf.close();
  if (verify) {
    if (verbose) print('Veryfing ${output.path} ...');
    var m = await readFileViaByteData(output.path);
    if (comp.length != m.length) {
      print('ERROR. Wrong length. Saved ${comp.length}, read ${m.length}');
    } else {
      for (var k in m.keys) {
        if (m[k]?.length != comp[k]?.length) {
          print('Wrong values for key "${k}"');
          //break;
        }
      }
    }
  }

  if (infoFile != null) {
    var info = File(infoFile);
    info.writeAsString(
        output.path.split('/').last +
            '\n${m.length} words\n${output.statSync().size} bytes\n',
        mode: FileMode.write);
  }

  if (verbose) print('DONE');
}

Future<Map<String, Uint8List>> readFileViaByteData(String fileName) async {
  var f = File(fileName);
  var b = f.readAsBytesSync();
  var m = readByteData(b.buffer.asByteData());
  return m;
}

Map<String, Uint8List> readByteData(ByteData file) {
  var m = Map<String, Uint8List>();

  var position = 0;

  var count = file.getInt32(position);
  position += 4;
  print(count);
  var counter = 0;

  while (position < file.lengthInBytes - 1 && counter < count) {
    counter++;

    var length = file.getInt32(position);
    position += 4;
    var bytes = file.buffer.asUint8List(position, length);
    var key = utf8.decode(bytes);
    position += length;

    length = file.getInt32(position);
    position += 4;
    bytes = file.buffer.asUint8List(position, length);
    position += length;

    m[key] = bytes;
  }

  return m;
}

int _readInt32(RandomAccessFile raf) {
  var int32 = Uint8List(4);
  if (raf.readIntoSync(int32) <= 0) return -1;
  var bd = ByteData.sublistView(int32);
  var val = bd.getInt32(0);
  return val;
}

Uint8List _readIntList(RandomAccessFile raf, int count) {
  var bytes = Uint8List(count);
  if (raf.readIntoSync(bytes) <= 0) return null;

  return bytes;
}

Future<Map<String, Uint8List>> readFile(String fileName) async {
  var f = File(fileName);
  var raf = await f.open();

  var count = _readInt32(raf);

  print('Reading ${count} entries from file ${fileName}');

  var m = Map<String, Uint8List>();

  while (true) {
    var length = _readInt32(raf);
    if (length < 0) break;
    var bytes = _readIntList(raf, length);
    if (bytes == null) break;
    var key = utf8.decode(bytes);
    length = _readInt32(raf);
    if (length < 0) break;
    var value = _readIntList(raf, length);
    m[key] = value ?? Uint8List(0);
  }

  return m;
}
