import 'package:dio/dio.dart';
import 'package:chatapp/api/config.dart';
import 'package:chatapp/controller/global/user_controller.dart';
import 'package:get/get.dart';

class DioUtil {
  static late Dio dio;
  // 该类的属性 dio 可以后续再定义，也就是可以随时随地初始化
  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: "${ApiConfig.baseUrl}/",
        connectTimeout: const Duration(seconds: 5),
        // 全局 keep-alive / close，每次请求是否新建 TCP，请求完立刻关闭，默认是 keep-alive 可以复用缓存 TCP 
        // 不过感觉效果不明显
        headers: {"Connection": "keep-alive"},
      ),
    );
    // 拦截器 onRequest拦截器组 → 真实网络 IO → onResponse / onError拦截器组
    // Gin：通过 gin.Context 共享数据（c.Set()）；
    // Dio：通过 RequestOptions.extra 自定义键值共享单次请求数据，上下文隔离。
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 默认需要 认证
          final bool noAuth = options.extra["noAuth"] ?? false;
          final token = Get.find<UserController>().token;
          if (!noAuth && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },
        onResponse: (resp, handler) {
          final raw = resp.data;
          if (raw is Map<String, dynamic>) {
            // 获取后端返回的 code 与 message 信息
            int bizCode = raw["code"] ?? -1;
            String msg = raw["message"] ?? "请求失败";

            if (bizCode != 200) {
              // 此处不 return 会进入 onError
              return handler.reject(
                DioException(
                  requestOptions: resp.requestOptions,
                  message: msg,
                  response: resp,
                ),
              );
            }

            // 上面已经剥离并处理了 code 和 message 此处只剩下 干净的 data 数据返回给 上层 没有的话就是 null
            resp.data = raw["data"];
          }
          return handler.next(resp);
        },
        onError: (err, handler) {
          String? errMsg;
          if (err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.receiveTimeout) {
            errMsg = ErrorMsgConstant.timeoutErr;
          } else if (err.type == DioExceptionType.connectionError) {
            errMsg = ErrorMsgConstant.connectErr;
          }
          final newErr = DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: err.type,
            error: err.error,
            message: errMsg,
          );
          return handler.reject(newErr);
        },
      ),
    );
  }
}

class ErrorMsgConstant {
  static const String networkDefaultErr = "网络异常，请稍后重试";
  static const String timeoutErr = "请求超时，请检查网络";
  static const String connectErr = "网络连接失败，请重试";
}

// class BaseResp {
//   int code;
//   String message;
//   Map<String, dynamic>? data;

//   // 自定义命名构造函数 可以自定义接收什么数据类型来给类进行初始化
//   BaseResp.fromJson(Map<String, dynamic> json)
//     // 初始化列表
//     : code = json["code"] ?? 0,
//       message = json["message"] ?? "",
//       data = json["data"];
// }
