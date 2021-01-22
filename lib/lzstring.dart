//Copied from https://github.com/skipness/lzstring-dart

import 'dart:math';
import 'dart:typed_data';

typedef GetCharFromInt = String Function(int a);
typedef GetNextValue = int Function(int index);

class _Data {
  int value, position, index;
  _Data(this.value, this.position, this.index);
}

class LZString {
  static final String _keyStrBase64 =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  static final String _keyStrUriSafe =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-\$';
  static final Map<String, Map<String, int>> _baseReverseDic =
      <String, Map<String, int>>{};

  static int _getBaseValue(String alphabet, String character) {
    if (!_baseReverseDic.containsKey(alphabet)) {
      _baseReverseDic[alphabet] = <String, int>{};
      for (var i = 0; i < alphabet.length; i++) {
        _baseReverseDic[alphabet]?[alphabet[i]] = i;
      }
    }
    return _baseReverseDic[alphabet]![character]!;
  }

  /// Produces ASCII UTF-16 strings representing the original string encoded in Base64 from [input].
  /// Can be decompressed with `decompressFromBase64`.
  ///
  /// This works by using only 6bits of storage per character. The strings produced are therefore 166% bigger than those produced by `compress`.
  static Future<String> compressToBase64(String input) async {
    if (input.isEmpty) return '';
    var res = await _compress(input, 6, (a) => _keyStrBase64[a]);
    switch (res.length % 4) {
      case 0:
        return res;
      case 1:
        return res + '===';
      case 2:
        return res + '==';
      case 3:
        return res + '=';
    }
    return '';
  }

  /// Decompress base64 [input] which produces by `compressToBase64`.
  static Future<String> decompressFromBase64(String input) async {
    if (input.isEmpty) return '';
    return await _decompress(input.length, 32,
        (index) => _getBaseValue(_keyStrBase64, input[index]));
  }

  /// Produces "valid" UTF-16 strings from [input].
  ///
  /// Can be decompressed with `decompressFromUTF16`.
  ///
  /// This works by using only 15 bits of storage per character. The strings produced are therefore 6.66% bigger than those produced by `compress`.
  static Future<String> compressToUTF16(String input) async {
    if (input.isEmpty) return '';
    return await _compress(input, 15, (a) => String.fromCharCode(a + 32)) + ' ';
  }

  /// Decompress "valid" UTF-16 string which produces by `compressToUTF16`
  static Future<String> decompressFromUTF16(String compressed) async {
    if (compressed.isEmpty) return '';
    return await _decompress(
        compressed.length, 16384, (index) => compressed.codeUnitAt(index) - 32);
  }

  /// Produces an uint8Array.
  ///
  /// Can be decompressed with `decompressFromUint8Array`
  static Future<Uint8List> compressToUint8Array(String uncompressed) async {
    var compressed = await compress(uncompressed);
    return Future<Uint8List>(() {
      var buf = Uint8List(compressed.length * 2);
      for (var i = 0, totalLen = compressed.length; i < totalLen; i++) {
        var currentValue = compressed.codeUnitAt(i);
        buf[i * 2] = currentValue >> 8;
        buf[i * 2 + 1] = currentValue % 256;
      }
      return buf;
    });
  }

  /// Decompress uint8Array which produces by `compressToUint8Array`.
  static Future<String> decompressFromUint8Array(Uint8List compressed) async {
    if (compressed.isEmpty) {
      return '';
    } else {
      var buf = List<int>.filled(
          compressed.length ~/ 2, 0); //List<int>(compressed.length ~/ 2);
      for (var i = 0, totalLen = buf.length; i < totalLen; i++) {
        buf[i] = compressed[i * 2] * 256 + compressed[i * 2 + 1];
      }
      var result = <String>[];
      buf.forEach((c) => result.add(String.fromCharCode(c)));
      return await decompress(result.join(''));
    }
  }

  /// Decompress ASCII strings [input] which produces by `compressToEncodedURIComponent`.
  static Future<String> decompressFromEncodedURIComponent(String input) async {
    if (input.isEmpty) return '';
    input = input.replaceAll(' ', '+');
    return await _decompress(input.length, 32,
        (index) => _getBaseValue(_keyStrUriSafe, input[index]));
  }

  /// Produces ASCII strings representing the original string encoded in Base64 with a few tweaks to make these URI safe.
  ///
  /// Can be decompressed with `decompressFromEncodedURIComponent`
  static Future<String> compressToEncodedURIComponent(String input) async {
    if (input.isEmpty) '';
    return await _compress(input, 6, (a) => _keyStrUriSafe[a]);
  }

  /// Produces invalid UTF-16 strings from [uncompressed].
  ///
  /// Can be decompressed with `decompress`.
  ///
  static Future<String> compress(final String uncompressed) async {
    return await _compress(uncompressed, 16, (a) => String.fromCharCode(a));
  }

  static Future<String> _compress(
      String uncompressed, int bitsPerChar, GetCharFromInt getCharFromInt) {
    return Future<String>(() {
      if (uncompressed.isEmpty) return '';
      int i, value;
      var contextDictionary = <String, int>{};
      var contextDictionaryToCreate = <String, bool>{};
      var contextC = '';
      var contextWC = '';
      var contextW = '';
      var contextEnlargeIn =
          2; // Compensate for the first entry which should not count
      var contextDictSize = 3;
      var contextNumBits = 2;
      var contextData = StringBuffer();
      var contextDataVal = 0;
      var contextDataPosition = 0;
      int ii;

      for (ii = 0; ii < uncompressed.length; ii++) {
        contextC = uncompressed[ii];
        if (!contextDictionary.containsKey(contextC)) {
          contextDictionary[contextC] = contextDictSize++;
          contextDictionaryToCreate[contextC] = true;
        }

        contextWC = contextW + contextC;
        if (contextDictionary.containsKey(contextWC)) {
          contextW = contextWC;
        } else {
          if (contextDictionaryToCreate.containsKey(contextW)) {
            if (contextW.codeUnitAt(0) < 256) {
              for (i = 0; i < contextNumBits; i++) {
                contextDataVal = (contextDataVal << 1);
                if (contextDataPosition == bitsPerChar - 1) {
                  contextDataPosition = 0;
                  contextData.write(getCharFromInt(contextDataVal));
                  contextDataVal = 0;
                } else {
                  contextDataPosition++;
                }
              }
              value = contextW.codeUnitAt(0);
              for (i = 0; i < 8; i++) {
                contextDataVal = (contextDataVal << 1) | (value & 1);
                if (contextDataPosition == bitsPerChar - 1) {
                  contextDataPosition = 0;
                  contextData.write(getCharFromInt(contextDataVal));
                  contextDataVal = 0;
                } else {
                  contextDataPosition++;
                }
                value = value >> 1;
              }
            } else {
              value = 1;
              for (i = 0; i < contextNumBits; i++) {
                contextDataVal = (contextDataVal << 1) | value;
                if (contextDataPosition == bitsPerChar - 1) {
                  contextDataPosition = 0;
                  contextData.write(getCharFromInt(contextDataVal));
                  contextDataVal = 0;
                } else {
                  contextDataPosition++;
                }
                value = 0;
              }
              value = contextW.codeUnitAt(0);
              for (i = 0; i < 16; i++) {
                contextDataVal = (contextDataVal << 1) | (value & 1);
                if (contextDataPosition == bitsPerChar - 1) {
                  contextDataPosition = 0;
                  contextData.write(getCharFromInt(contextDataVal));
                  contextDataVal = 0;
                } else {
                  contextDataPosition++;
                }
                value = value >> 1;
              }
            }
            contextEnlargeIn--;
            if (contextEnlargeIn == 0) {
              contextEnlargeIn = pow(2, contextNumBits).toInt();
              contextNumBits++;
            }
            contextDictionaryToCreate.remove(contextW);
          } else {
            value = contextDictionary[contextW]!;
            for (i = 0; i < contextNumBits; i++) {
              contextDataVal = (contextDataVal << 1) | (value & 1);
              if (contextDataPosition == bitsPerChar - 1) {
                contextDataPosition = 0;
                contextData.write(getCharFromInt(contextDataVal));
                contextDataVal = 0;
              } else {
                contextDataPosition++;
              }
              value = value >> 1;
            }
          }
          contextEnlargeIn--;
          if (contextEnlargeIn == 0) {
            contextEnlargeIn = pow(2, contextNumBits).toInt();
            contextNumBits++;
          }
          // Add wc to the dictionary.
          contextDictionary[contextWC] = contextDictSize++;
          contextW = contextC;
        }
      }

      // Output the code for w.
      if (contextW != '') {
        if (contextDictionaryToCreate.containsKey(contextW)) {
          if (contextW.codeUnitAt(0) < 256) {
            for (i = 0; i < contextNumBits; i++) {
              contextDataVal = (contextDataVal << 1);
              if (contextDataPosition == bitsPerChar - 1) {
                contextDataPosition = 0;
                contextData.write(getCharFromInt(contextDataVal));
                contextDataVal = 0;
              } else {
                contextDataPosition++;
              }
            }
            value = contextW.codeUnitAt(0);
            for (i = 0; i < 8; i++) {
              contextDataVal = (contextDataVal << 1) | (value & 1);
              if (contextDataPosition == bitsPerChar - 1) {
                contextDataPosition = 0;
                contextData.write(getCharFromInt(contextDataVal));
                contextDataVal = 0;
              } else {
                contextDataPosition++;
              }
              value = value >> 1;
            }
          } else {
            value = 1;
            for (i = 0; i < contextNumBits; i++) {
              contextDataVal = (contextDataVal << 1) | value;
              if (contextDataPosition == bitsPerChar - 1) {
                contextDataPosition = 0;
                contextData.write(getCharFromInt(contextDataVal));
                contextDataVal = 0;
              } else {
                contextDataPosition++;
              }
              value = 0;
            }
            value = contextW.codeUnitAt(0);
            for (i = 0; i < 16; i++) {
              contextDataVal = (contextDataVal << 1) | (value & 1);
              if (contextDataPosition == bitsPerChar - 1) {
                contextDataPosition = 0;
                contextData.write(getCharFromInt(contextDataVal));
                contextDataVal = 0;
              } else {
                contextDataPosition++;
              }
              value = value >> 1;
            }
          }
          contextEnlargeIn--;
          if (contextEnlargeIn == 0) {
            contextEnlargeIn = pow(2, contextNumBits).toInt();
            contextNumBits++;
          }
          contextDictionaryToCreate.remove(contextW);
        } else {
          value = contextDictionary[contextW]!;
          for (i = 0; i < contextNumBits; i++) {
            contextDataVal = (contextDataVal << 1) | (value & 1);
            if (contextDataPosition == bitsPerChar - 1) {
              contextDataPosition = 0;
              contextData.write(getCharFromInt(contextDataVal));
              contextDataVal = 0;
            } else {
              contextDataPosition++;
            }
            value = value >> 1;
          }
        }
        contextEnlargeIn--;
        if (contextEnlargeIn == 0) {
          contextEnlargeIn = pow(2, contextNumBits).toInt();
          contextNumBits++;
        }
      }

      // Mark the end of the stream
      value = 2;
      for (i = 0; i < contextNumBits; i++) {
        contextDataVal = (contextDataVal << 1) | (value & 1);
        if (contextDataPosition == bitsPerChar - 1) {
          contextDataPosition = 0;
          contextData.write(getCharFromInt(contextDataVal));
          contextDataVal = 0;
        } else {
          contextDataPosition++;
        }
        value = value >> 1;
      }

      // Flush the last char
      while (true) {
        contextDataVal = (contextDataVal << 1);
        if (contextDataPosition == bitsPerChar - 1) {
          contextData.write(getCharFromInt(contextDataVal));
          break;
        } else {
          contextDataPosition++;
        }
      }
      return contextData.toString();
    });
  }

  /// Decompress invalid UTF-16 strings which produces by `compress`.
  static Future<String> decompress(final String compressed) async {
    if (compressed.isEmpty) return '';
    return await _decompress(
        compressed.length, 32768, (index) => compressed.codeUnitAt(index));
  }

  static Future<String> _decompress(
      int length, int resetValue, GetNextValue getNextValue) {
    return Future<String>(() {
      var dictionary = <int, String>{};
      int enLargeIn = 4,
          dictSize = 4,
          numBits = 3,
          i,
          bits,
          maxpower,
          power,
          resb;
      var entry = '', c = '', w = '';
      var result = StringBuffer();
      var data = _Data(getNextValue(0), resetValue, 1);

      for (i = 0; i < 3; i++) {
        dictionary[i] = i.toString();
      }

      bits = 0;
      maxpower = pow(2, 2).toInt();
      power = 1;
      while (power != maxpower) {
        resb = data.value & data.position;
        data.position >>= 1;
        if (data.position == 0) {
          data.position = resetValue;
          data.value = getNextValue(data.index++);
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }

      var next = bits;
      switch (next) {
        case 0:
          bits = 0;
          maxpower = pow(2, 8).toInt();
          power = 1;
          while (power != maxpower) {
            resb = data.value & data.position;
            data.position >>= 1;
            if (data.position == 0) {
              data.position = resetValue;
              data.value = getNextValue(data.index++);
            }
            bits |= (resb > 0 ? 1 : 0) * power;
            power <<= 1;
          }
          c = String.fromCharCode(bits);
          break;
        case 1:
          bits = 0;
          maxpower = pow(2, 16).toInt();
          power = 1;
          while (power != maxpower) {
            resb = data.value & data.position;
            data.position >>= 1;
            if (data.position == 0) {
              data.position = resetValue;
              data.value = getNextValue(data.index++);
            }
            bits |= (resb > 0 ? 1 : 0) * power;
            power <<= 1;
          }
          c = String.fromCharCode(bits);
          break;
        case 2:
          return '';
      }
      dictionary[3] = c;
      w = c;
      result.write(c);
      while (true) {
        if (data.index > length) return '';
        bits = 0;
        maxpower = pow(2, numBits).toInt();
        power = 1;
        while (power != maxpower) {
          resb = data.value & data.position;
          data.position >>= 1;
          if (data.position == 0) {
            data.position = resetValue;
            data.value = getNextValue(data.index++);
          }
          bits |= (resb > 0 ? 1 : 0) * power;
          power <<= 1;
        }

        int cc;
        switch (cc = bits) {
          case 0:
            bits = 0;
            maxpower = pow(2, 8).toInt();
            power = 1;
            while (power != maxpower) {
              resb = data.value & data.position;
              data.position >>= 1;
              if (data.position == 0) {
                data.position = resetValue;
                data.value = getNextValue(data.index++);
              }
              bits |= (resb > 0 ? 1 : 0) * power;
              power <<= 1;
            }
            dictionary[dictSize++] = String.fromCharCode(bits);
            cc = dictSize - 1;
            enLargeIn--;
            break;
          case 1:
            bits = 0;
            maxpower = pow(2, 16).toInt();
            power = 1;
            while (power != maxpower) {
              resb = data.value & data.position;
              data.position >>= 1;
              if (data.position == 0) {
                data.position = resetValue;
                data.value = getNextValue(data.index++);
              }
              bits |= (resb > 0 ? 1 : 0) * power;
              power <<= 1;
            }
            dictionary[dictSize++] = String.fromCharCode(bits);
            cc = dictSize - 1;
            enLargeIn--;
            break;
          case 2:
            return result.toString();
        }

        if (enLargeIn == 0) {
          enLargeIn = pow(2, numBits).toInt();
          numBits++;
        }

        if (cc < dictionary.length && dictionary.containsKey(cc)) {
          entry = dictionary[cc]!;
        } else {
          if (cc == dictSize) {
            entry = w + w[0];
          } else {
            return '';
          }
        }
        result.write(entry);

        // Add w+entry[0] to the dictionary.
        dictionary[dictSize++] = w + entry[0];
        enLargeIn--;

        w = entry;

        if (enLargeIn == 0) {
          enLargeIn = pow(2, numBits).toInt();
          numBits++;
        }
      }
    });
  }
}
