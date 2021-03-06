import 'analyzed_class.dart';
import 'compile_metadata.dart';
import 'identifiers.dart';
import 'output/convert.dart';
import 'output/output_ast.dart';
import 'template_ast.dart';

/// Augments [TemplateAst]s with additional information to enable optimizations.
///
/// This information can't be provided during construction of the [TemplateAst]s
/// as it may not exist yet at the time it is needed.
class OptimizeTemplateAstVisitor extends TemplateAstVisitor<dynamic, Null> {
  final CompileDirectiveMetadata _component;

  OptimizeTemplateAstVisitor(this._component);

  @override
  void visitNgContent(NgContentAst ast, _) {}

  @override
  void visitEmbeddedTemplate(EmbeddedTemplateAst ast, _) {
    _typeNgForLocals(_component, ast.directives, ast.variables);
    templateVisitAll(this, ast.children);
  }

  @override
  void visitElement(ElementAst ast, _) {
    templateVisitAll(this, ast.children);
  }

  @override
  void visitReference(ReferenceAst ast, _) {}

  @override
  void visitVariable(VariableAst ast, _) {}

  @override
  void visitEvent(BoundEventAst ast, _) {}

  @override
  void visitElementProperty(BoundElementPropertyAst ast, _) {}

  @override
  void visitAttr(AttrAst ast, _) {}

  @override
  void visitBoundText(BoundTextAst ast, _) {}

  @override
  void visitText(TextAst ast, _) {}

  @override
  void visitDirective(DirectiveAst ast, _) {}

  @override
  void visitDirectiveProperty(BoundDirectivePropertyAst ast, _) {}
}

/// Adds type information to the [VariableAst]s of `NgFor` locals.
///
/// This type information is used to type-annotate the local variable
/// declarations, which would otherwise be dynamic as they're retrieved from a
/// dynamic map.
void _typeNgForLocals(
  CompileDirectiveMetadata component,
  List<DirectiveAst> directives,
  List<VariableAst> variables,
) {
  final ngFor = directives.firstWhere(
      (directive) =>
          directive.directive.type.moduleUrl ==
          Identifiers.NG_FOR_DIRECTIVE.moduleUrl,
      orElse: () => null);
  if (ngFor == null) return; // No `NgFor` to optimize.
  final ngForOf = ngFor.inputs.firstWhere(
      (input) => input.templateName == 'ngForOf',
      orElse: () => null);
  if (ngForOf == null) return; // No [ngForOf] binding from which to get type.
  final ngForOfType = getExpressionType(ngForOf.value, component.analyzedClass);
  // Augment locals set by `NgFor` with type information.
  for (var variable in variables) {
    switch (variable.value) {
      case r'$implicit':
        // This local is the generic type of the `Iterable` bound to [ngForOf].
        final iterableItemType = getIterableElementType(ngForOfType);
        if (iterableItemType != null) {
          variable.type = fromDartType(iterableItemType);
        }
        break;
      case 'index':
      case 'count':
        // These locals are always integers.
        variable.type = INT_TYPE;
        break;
      case 'first':
      case 'last':
      case 'even':
      case 'odd':
        // These locals are always booleans.
        variable.type = BOOL_TYPE;
        break;
    }
  }
}
