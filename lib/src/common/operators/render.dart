import 'package:graphic/src/dataflow/operator.dart';
import 'package:graphic/src/graffiti/graffiti.dart';

/// Render operator holds scene as effect. It has no value.
/// The scene is set in constructor an can not be reset.
/// Modify the scene by render method.
abstract class Render<S extends Scene> extends Operator {
  Render(
    Map<String, dynamic> params,
    this.scene,
  ) : super(params);

  final S scene;

  @override
  evaluate() {
    render();
  }

  void render();
}
