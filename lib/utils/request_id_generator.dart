
import 'package:nanoid/nanoid.dart';

class RequestIdGenerator {
  RequestIdGenerator._();
  static String generate() {
    final randomStr = nanoid(12);
    return "req_$randomStr";
  }
}