import 'dart:mirrors';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:collection/collection.dart';

String parseClass(ClassMirror classMirror, String lib, Map<String, Set<Type>> generate, Set<Type> unfolded) {
  var path = classMirror.location!.sourceUri.path.replaceAll('/', r'\');
  print(path);
  if(path == '_http') path = '_http\\http.dart';
  final analysis = parseFile(
    path: path.contains(r':\') ? path.substring(1) : r'C:\src\flutter\bin\cache\dart-sdk\lib\' + path, 
    featureSet: FeatureSet.latestLanguageVersion()
  );
  final className = parseSymbol(classMirror.simpleName);
  final classAnalysis = analysis.unit.declarations.whereType<ClassDeclaration>().firstWhere((element) => element.name.lexeme == className);
  final classLower = className[0].toLowerCase() + className.substring(1);

  final typesSet = <Symbol>{};

  typesSet.add(classMirror.qualifiedName);

  final methods = classAnalysis.members.whereType<MethodDeclaration>();
  final fields = classAnalysis.members.whereType<FieldDeclaration>();
  final arguments = asString(classAnalysis.typeParameters);

  final mixins = classAnalysis.implementsClause?.interfaces
    .where((interface) => unfolded.map((e) => e.toString().split('<').first)
      .contains(interface.name.name));

  String withString = mixins
    ?.map((e) => '${e.name.name}Mixin${e.typeArguments ?? '' }')
    .join(', ') ?? '';

  String mixinImportsString = mixins?.map<String>((interface) {
    String classFileName = StringUtils.camelCaseToLowerUnderscore(interface.name.name);
    String libName = generate.entries.firstWhere((element) => element.value.map((e) => e.toString().split('<').first,).contains(interface.name.name.toString())).key;
    print('name: $libName lib: $lib');

    if(libName == lib) {
      return 'import \'./$classFileName.dart\';';
    }

    return 'import \'../$libName/$classFileName.dart\';';
  }).join('\n') ?? '';

// $mixinImportsString
// ${withString.isNotEmpty ? '$withString, ' : ''}
// ${mixins != null ? ', ' : ''}${mixins?.map((e) => e.name.name[0].toLowerCase() + e.name.name.substring(1)).join(', ')}
// ${withString.isNotEmpty ? 'on $withString' : ''}
  String result = '''import 'package:meta/meta.dart';

/// ```dart
/// class My$className with ${className}Mixin$arguments implements $className$arguments { 
///   // Must override 
///   @override 
///   $className get $classLower;
///   ...
/// }
/// ```
mixin ${className}Mixin$arguments implements $className$arguments {
\t@protected
\t$className$arguments get $classLower;

''';
  for(final field in fields) {
    final type = field.fields.childEntities.whereType<NamedType>().firstOrNull ?? field.fields.childEntities.whereType<GenericFunctionType>().firstOrNull;
    final fieldDeclaration = field.fields.childEntities.whereType<VariableDeclaration>().firstOrNull;
    final name = fieldDeclaration?.name;
    if(name.toString().startsWith('_')) {
      continue;
    }
    if(field.isStatic) {
      continue;
    }

    final fieldMirror = classMirror.declarations.values.whereType<VariableMirror>().firstWhereOrNull((element) => parseSymbol(element.simpleName) == name?.toString());
    typesSet.addAll(getParameters(fieldMirror?.type));

    result += '\t@override\n';
    result += '\t${type ?? 'dynamic'} get $name => $classLower.$name;\n\n';
    
    if(!fieldDeclaration!.isFinal) {
      result += '\t@override\n';
      result += '\tset $name(${type ?? 'dynamic'} value) => $classLower.$name = value;\n\n';
    }
  }

  for (final method in methods) {
    if(method.name.toString().startsWith('_')) {
      continue;
    }

    if(method.isStatic) {
      continue;
    }

    if(method.returnType != null) {
      final methodMirror = classMirror.declarations.values.whereType<MethodMirror>().firstWhereOrNull((element) => parseSymbol(element.simpleName) == method.name.toString());
      
      typesSet.addAll(getParameters(methodMirror?.returnType));
      typesSet.addAll(methodMirror?.parameters.map((e) => getParameters(e.type)).expand((element) => element) ?? {});
    }

    result += '\t@override\n';

    String setter = method.isSetter ? 'set' : method.returnType.toString();
    String getter = method.isGetter ? ' get' : '';
    String name = method.name.toString();
    String? call = method.isGetter ? '' : method.isSetter ? ' = ${method.parameters?.parameters.first.name}'   : method.parameters?.parameters.map((e) => e.isNamed ? '${e.name}: ${e.name}' : e.name).join(', ');
    String callString = name == '[]' ? '[$call]' : method.isGetter ? '' : method.isSetter ? call ?? '' : '(${call ?? ''})';

    result += '\t$setter$getter ${method.isOperator ? 'operator' : ''}$name${asString(method.typeParameters)}${method.isGetter ? '' : method.parameters} => $classLower${method.isOperator ? '' : '.'}${name == '[]' ? '' : name}$callString;\n\n'
      .replaceAll(RegExp(r'@Since\(\"[0-9]+\.[0-9]+\"\)', multiLine: true), '');
      
  }
  
  result = '${typesSet
    .map<List<String>>((e) => parseSymbol(e).split('.'))
    .where((e) => e.length == 3)
    .whereNot((e) => e[1] == 'core')
    .map((e) => e.sublist(0, 2).join(':'))
    .map((e) => e == 'dart:_http' ? 'dart:io' : e)
    .toSet()
    .map((e) => 'import \'$e\';')
    .join('\n')}\n$result';

  // final arguments = classMirror.typeVariables.isNotEmpty ? '<${classMirror.typeVariables.map((e) => parseSymbol(e.simpleName)).join(', ')}>' : '';
  // final staticMethods = classMirror.staticMembers.values.map((e) => e.simpleName);
  // final publicFields = classMirror.declarations.values.where((field) => !field.isPrivate).where((element) => !staticMethods.contains(element.simpleName));

  // // mixin `className`Mixin implements `className` {
  // result += 'mixin ${className}Mixin$arguments implements $className$arguments {\n';
  // // @protected
  // // `classType` get `className (starts with lowercase);`
  // result += '\t@protected\n';
  // result += '\t$className$arguments get ${className[0].toLowerCase() + className.substring(1)};\n';

  // for(final variableMirror in publicFields.whereType<VariableMirror>()) {
  //   result += parseVariable(variableMirror);
  // }

  // for(final methodMirror in publicFields.whereType<MethodMirror>()) {
  //   result += parseMethod(methodMirror);
  // } 

  result += '}\n';

  return result;
}

Set<Symbol> getParameters(TypeMirror? type) {
  if(type == null) {
    return {};
  }

  Set<Symbol> result = {};

  if(type is FunctionTypeMirror) {
    result.addAll(getParameters(type.returnType));
    result.addAll(type.parameters.map((e) => getParameters(e.type)).expand((element) => element));
  } else {
    result.add(type.qualifiedName);
  }

  return result;
} 

String asString(Object? value) => value == null ? '' : value.toString(); 

// String parseVariable(VariableMirror variableMirror) {
//   final className = parseSymbol(variableMirror.owner!.simpleName);  
//   final classNameLowercase = className[0].toLowerCase() + className.substring(1);
//   final name = parseSymbol(variableMirror.simpleName);
//   String result = '';

  
//   // `returnType` get `name` => `classInstanceGetter`.`name`;
//   result += '\n';
//   result += '\t${parseType(variableMirror.type)} get $name => $classNameLowercase.$name;\n';
  
//   // set `name`(`parameter.first`) => `classInstanceGetter`.`name` = `parameter.first`;
//   result += '\n';
//   result += '\tset $name(${parseType(variableMirror.type)} value) => $className.$name = value;\n' ;

//   return result;
// }

// String parseMethod(MethodMirror methodMirror) {
//   final className = parseSymbol(methodMirror.owner!.simpleName);
//   final classNameLowercase = className[0].toLowerCase() + className.substring(1);
//   final methodName = parseSymbol(methodMirror.simpleName);
//   String result = '\n';

//   result += '\t@override\n';
//   if(methodMirror.isRegularMethod) {
//     // `returnType` `name`(`parameters`) => `classInstanceGetter`.`name`(`parameter names`);
//     result += '\t${parseType(methodMirror.returnType)} $methodName(${parseParameters(methodMirror.parameters)})';
//     result += ' => $classNameLowercase.$methodName(${
//         methodMirror.parameters.map((e) => 
//           '${e.isNamed ? '${parseSymbol(e.simpleName)}: ' : ''} ${parseSymbol(e.simpleName)}'
//         ).join(', ')
//       });\n';
//   } else if(methodMirror.isGetter) {
//     // `returnType` get `name` => `classInstanceGetter`.`name`;
//     result += '\t${parseType(methodMirror.returnType)} get $methodName => $classNameLowercase.$methodName;\n';
//   } else if(methodMirror.isSetter) {
//     var name = methodName;
//     name = name.substring(0, name.length - 2);
//     // set `name-1`(`parameter.first`) => `classInstanceGetter`.`name -1` = `parameter.first`;
//     result += '\tset $name(${parseParameter(methodMirror.parameters.first)}) => $classNameLowercase.$name = ${parseSymbol(methodMirror.parameters.first.simpleName)};\n';
//   } else {
//     return '';
//   }
  
//   return result;
// }

// String parseParameters(List<ParameterMirror> parametersMirror) {
//   String result = '';
  
//   final unNamed = parametersMirror.where((element) => !element.isNamed);
//   final optional = unNamed.where((element) => element.isOptional);
//   final named = parametersMirror.where((element) => element.isOptional);

//   if(unNamed.isNotEmpty) {
//     result += '${unNamed.map(parseParameter).join(', ')},';
//   } else if(optional.isNotEmpty) {
//     result += '[${optional.map(parseParameter).join(', ')}]';
//   } else if(named.isNotEmpty) {
//     result += '{${named.map(parseParameter).join(', ')}}';
//   }

//   return result;
// }

// String parseParameter(ParameterMirror parameterMirror) {
//   String result = '';
  
//   // `type` `name` = `default`
//   result += '${parseType(parameterMirror.type)} ${parseSymbol(parameterMirror.simpleName)}';
//   if(parameterMirror.hasDefaultValue) {
//     result += ' = ${parameterMirror.defaultValue!.reflectee.toString()}';
//   }

//   return result;
// }

// String parseType(TypeMirror typeMirror) {
//   String result = '';
  
//   if(typeMirror is FunctionTypeMirror) {
//     // `return type` Function(`parameters`)
//     result += '${parseType(typeMirror.returnType)} Function(${typeMirror.parameters.map((e) => parseType(e.type)).join(', ')})';
//   } else {
//     // `type`
//     result += parseSymbol(typeMirror.simpleName);
//   }

//   if(typeMirror.typeVariables.isNotEmpty) {
//     result += '<${typeMirror.typeVariables.map((e) => parseSymbol(e.simpleName)).join(', ')}>';
//   }

//   return result;
// }

String parseSymbol(Symbol symbol) => MirrorSystem.getName(symbol);
