import 'dart:io';
import 'dart:mirrors';
import 'package:basic_utils/basic_utils.dart';
import 'package:collection/collection.dart';
import 'package:core_mixins_gen/core_mixins_gen.dart';
import 'package:path/path.dart';

import 'generate.dart';

const sdkPath = r'C:\src\flutter\bin\cache\dart-sdk\lib\';

final Set<Type> unfolded = generate.values.expand((i) => i).toSet();

void main(List<String> arguments) {
  final String output = arguments.elementAtOrNull(1) ?? r'.\core_mixins\lib';
  Directory(output).createSync();
  for(final lib in generate.keys) {
    print('Generating $lib');
    final classes = generate[lib];
    Directory(join(output, lib)).createSync();
    for(final classType in classes!) {
      print(classType);
      final path = join(output, lib, '${StringUtils.camelCaseToLowerUnderscore(classType.toString().split('<').first)}.dart' ); 
      print('Generating $path');
      final classMirror = reflectClass(classType);
      File(path).writeAsStringSync(parseClass(classMirror, lib, generate, unfolded));
    }
  }
}


