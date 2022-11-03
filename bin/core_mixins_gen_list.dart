import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart';

const sdkPath = r'C:\src\flutter\bin\cache\dart-sdk\lib\';

final libs = <String>{
  'async',
  // 'collection',
  'convert',
  // 'developer',
  // 'ffi',
  'io',
  // 'isolate',
  // 'math',
  // 'mirrors',
  // 'typed_data',
};

final except = {
  'FutureOr',
};

void main(List<String> arguments) {
  print('Generating imports file.');
  String result = libs.map((e) => 'import \'dart:$e\' as $e;').join('\n');
  
  result += '\n\n';
  result += 'final Map<String, Set<Type>> generate = {\n';

  for(final lib in libs) {
    print('Parsing $lib.');
    final libPath = join(sdkPath, lib);
    final libAnalysis = parseFile(
      path: join(libPath, '$lib.dart'), 
      featureSet: FeatureSet.latestLanguageVersion(),
    );

    result += '\t\'$lib\': {\n';

    for(final module in libAnalysis.unit.childEntities.whereType<PartDirective>()) {
      final file = module.childEntities.whereType<SimpleStringLiteral>().first;
      print('Parsing $lib.$file');
      final moduleAnalysis = parseFile(
        path: join(libPath, file.value), 
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      for(final classDeclaration in moduleAnalysis.unit.declarations.whereType<ClassDeclaration>()) {
        if(classDeclaration.name.toString().startsWith('_')) continue;
        // if(classDeclaration.abstractKeyword == null) continue;
        if(except.contains(classDeclaration.name.toString())) continue;


        result += '\t\t$lib.${classDeclaration.name},\n';
      }
    }

    result += '\t},\n';
  }
  result += '};\n';

  File(r'.\bin\generate.dart').writeAsStringSync(result);
  return;
}


