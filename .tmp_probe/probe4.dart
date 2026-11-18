class R {}
class P {
  List<R> get v => null as dynamic;
  List<R> f() => null as dynamic;
}
class L { late List<R> f; }
List<R> typed() => null as dynamic;
void main() {
  final dynamic p = P();
  try { p.v; } catch (e) { print('A dynamic-getter: $e'); }
  try { p.f(); } catch (e) { print('B dynamic-method: $e'); }
  try { final dynamic fn = typed; print(fn()); } catch (e) { print('C dynamic-fn-call: $e'); }
  try { Function.apply(typed, const []); } catch (e) { print('D apply: $e'); }
  try { L().f; } catch (e) { print('E late: $e'); }
  try { [1].map((_) => typed()).toList(); } catch (e) { print('F map: $e'); }
  try { final Iterable<List<R>> it = [typed()]; print(it.first); } catch (e) { print('G iter: $e'); }
}
