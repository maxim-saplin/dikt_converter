import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: import_of_legacy_library_into_null_safe
import 'package:archive/archive.dart';
import 'package:dikt_converter/lzstring.dart';

void testOnFile() async {
  var f = File('./En-En-WordNet3-00.json');
  var s = await f.readAsString();
  await test(s);
}

Future<void> test(String jsonString) async {
  Map mm = json.decode(jsonString);
  var m = mm.cast<String, String>();
  var decomp = <String>[];
  for (var i = 0; i < 1; i++) {
    Map<String, Uint8List> comp;

    comp = deflate(m, 0);
    decomp.add(inflate(comp, 0));
    comp = deflate(m, 1);
    decomp.add(inflate(comp, 1));
    comp = deflate(m, 6);
    decomp.add(inflate(comp, 6));
    comp = deflate(m, 9);
    decomp.add(inflate(comp, 9));

    comp = gzip(m, 0);
    decomp.add(gzipDecomp(comp, 0));
    comp = gzip(m, 1);
    decomp.add(gzipDecomp(comp, 1));
    comp = gzip(m, 6);
    decomp.add(gzipDecomp(comp, 6));
    comp = gzip(m, 9);
    decomp.add(gzipDecomp(comp, 9));

    comp = zlib(m, 0);
    decomp.add(zlibDecomp(comp, 0));
    comp = zlib(m, 1);
    decomp.add(zlibDecomp(comp, 1));
    comp = zlib(m, 6);
    decomp.add(zlibDecomp(comp, 6));
    comp = zlib(m, 9);
    decomp.add(zlibDecomp(comp, 9));

    comp = gzipDart(m, 0);
    decomp.add(gzipDartDecomp(comp, 0));
    comp = gzipDart(m, 1);
    decomp.add(gzipDartDecomp(comp, 1));
    comp = gzipDart(m, 6);
    decomp.add(gzipDartDecomp(comp, 6));
    comp = gzipDart(m, 9);
    decomp.add(gzipDartDecomp(comp, 9));

    comp = zlibDartIo(m, 0);
    decomp.add(zlibDartIoDecomp(comp, 0));
    comp = zlibDartIo(m, 1);
    decomp.add(zlibDartIoDecomp(comp, 1));
    comp = zlibDartIo(m, 6);
    decomp.add(zlibDartIoDecomp(comp, 6));
    comp = zlibDartIo(m, 9);
    decomp.add(zlibDartIoDecomp(comp, 9));

    comp = await lzComp(m, 0);

//BZip2 is super slow and gives poorer compression ratio

// BZip2: 22886.00(ms)
//  Uncompressed/Compressed:
//  7.49Mb / 3.10Mb
//  2.41 - ratio
// BZip2 decoding: 13955.00 (ms)

// ZLib: 911.00(ms)
//  Uncompressed/Compressed:
//  7.49Mb / 2.64Mb
//  2.84 - ratio
// ZLib decoding: 165.00 (ms)

    // comp = bzip2(m);
    // bzip2Decomp(comp);

    print(' - ');
    decomp.add(' - ');
  }
  print(' --- ');
  for (var i in decomp) {
    print(i);
  }
}

class _CompUncomp {
  var uncompressed = 0;
  var compressed = 0;
  Map<String, Uint8List> m = {};
}

Map<String, Uint8List> zlib(Map<String, String> m, int level,
    [bool verbose = true]) {
  var comp = (Map<String, String> m) {
    var cu = _CompUncomp();
    var enc = ZLibEncoder();
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var gzipBytes = enc.encode(bytes, level: level);
      var b = Uint8List.fromList(gzipBytes);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'ZLib (level: ${level})', comp, verbose);
}

String zlibDecomp(Map<String, Uint8List> m, int level) {
  var sw = Stopwatch();
  sw.start();
  var dec = ZLibDecoder();
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    dec.decodeBytes(b);
  }
  sw.stop();
  return 'ZLib (level: ${level}) decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

Map<String, Uint8List> deflate(Map<String, String> m, int level,
    [bool verbose = true]) {
  var comp = (Map<String, String> m) {
    var cu = _CompUncomp();
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var def = Deflate(bytes, level: level).getBytes();
      var b = Uint8List.fromList(def);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'Deflate (level: ${level})', comp, verbose);
}

String inflate(Map<String, Uint8List> m, int level) {
  var sw = Stopwatch();
  sw.start();
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    Inflate(b).getBytes();
  }
  sw.stop();
  return 'Inflate (level: ${level}) decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

// Only turning on raw makes a difference, thoug encoded with raw true can't be decoded with raw false
Map<String, Uint8List> zlibDartIo(Map<String, String> m, int level) {
  var comp = (Map<String, String> m) {
    var cu = _CompUncomp();
    var enc = ZLibCodec(
            level: level,
            memLevel: ZLibOption.maxMemLevel,
            raw: true,
            strategy: ZLibOption.strategyDefault)
        .encoder;
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var gzipBytes = enc.convert(bytes);
      var b = Uint8List.fromList(gzipBytes);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'ZLib dart:io (level: ${level})', comp);
}

String zlibDartIoDecomp(Map<String, Uint8List> m, int level) {
  var sw = Stopwatch();
  sw.start();
  var dec = ZLibCodec(raw: true).decoder;
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    dec.convert(b);
  }
  sw.stop();
  return 'ZLib dart:io (level: ${level}) decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

Map<String, Uint8List> gzipDart(Map<String, String> m, int level) {
  var comp = (Map<String, String> m) {
    var cu = _CompUncomp();
    var enc = GZipCodec(
            level: level,
            memLevel: ZLibOption.maxMemLevel,
            raw: true,
            strategy: ZLibOption.strategyDefault)
        .encoder;
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var gzipBytes = enc.convert(bytes);
      var b = Uint8List.fromList(gzipBytes);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'GZip dart:io (level: ${level})', comp);
}

String gzipDartDecomp(Map<String, Uint8List> m, int level) {
  var sw = Stopwatch();
  sw.start();
  var dec = GZipCodec(raw: true).decoder;
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    dec.convert(b);
  }
  sw.stop();
  return 'GZip dart:io (level: ${level}) decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

Map<String, Uint8List> gzip(Map<String, String> m, int level) {
  var func = (Map<String, String> m) {
    var cu = _CompUncomp();
    var enc = GZipEncoder();
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var gzipBytes = enc.encode(bytes, level: level) ?? [];
      var b = Uint8List.fromList(gzipBytes);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'GZip (level: ${level})', func);
}

String gzipDecomp(Map<String, Uint8List> m, int level) {
  var sw = Stopwatch();
  sw.start();
  var dec = GZipDecoder();
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    dec.decodeBytes(b);
  }
  sw.stop();
  return 'GZip (level: ${level})  decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

Future<Map<String, Uint8List>> lzComp(Map<String, String> m, int level) {
  var func = (Map<String, String> m) async {
    var cu = _CompUncomp();

    for (var e in m.entries) {
      var bytes = await LZString.compressToUint8Array(e.value);
      var bb = utf8.encode(e.value);
      cu.uncompressed += bb.length;
      cu.compressed += bytes.length;
      cu.m[e.key] = bytes;
    }
    return cu;
  };

  return _commonAsync(m, 'LZ (level: ${level})', func);
}

Map<String, Uint8List> bzip2(Map<String, String> m) {
  var func = (Map<String, String> m) {
    var cu = _CompUncomp();
    var enc = BZip2Encoder();
    for (var e in m.entries) {
      var bytes = utf8.encode(e.value);
      cu.uncompressed += bytes.length;
      var gzipBytes = enc.encode(bytes);
      var b = Uint8List.fromList(gzipBytes);
      cu.compressed += b.length;
      cu.m[e.key] = b;
    }
    return cu;
  };

  return _common(m, 'BZip2', func);
}

String bzip2Decomp(Map<String, Uint8List> m) {
  var sw = Stopwatch();
  sw.start();
  var dec = BZip2Decoder();
  for (var e in m.entries) {
    var b = Uint8List.fromList(e.value);
    dec.decodeBytes(b);
  }
  sw.stop();
  return 'BZip2 decoding: ' +
      sw.elapsedMilliseconds.toStringAsFixed(2) +
      ' (ms)';
}

Map<String, Uint8List> _common(Map<String, String> m, String name,
    _CompUncomp Function(Map<String, String> m) func,
    [bool verbose = true]) {
  var sw = Stopwatch();
  sw.start();

  var cu = func(m);

  sw.stop();

  if (verbose) {
    print(name +
        ': ' +
        sw.elapsedMilliseconds.toStringAsFixed(2) +
        '(ms)' +
        ' - Compression ratio: ${(cu.uncompressed / cu.compressed).toStringAsFixed(2)}' +
        ' (${(cu.uncompressed / 1024 / 1024).toStringAsFixed(2)}Mb/' +
        (cu.compressed / 1024 / 1024).toStringAsFixed(2) +
        'Mb)');
  }

  return cu.m;
}

Future<Map<String, Uint8List>> _commonAsync(Map<String, String> m, String name,
    Future<_CompUncomp> Function(Map<String, String> m) func,
    [bool verbose = true]) async {
  var sw = Stopwatch();
  sw.start();

  var cu = await func(m);

  sw.stop();

  if (verbose) {
    print(name +
        ': ' +
        sw.elapsedMilliseconds.toStringAsFixed(2) +
        '(ms)' +
        ' - Compression ratio: ${(cu.uncompressed / cu.compressed).toStringAsFixed(2)}' +
        ' (${(cu.uncompressed / 1024 / 1024).toStringAsFixed(2)}Mb/' +
        (cu.compressed / 1024 / 1024).toStringAsFixed(2) +
        'Mb)');
  }

  return cu.m;
}
