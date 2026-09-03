class ApiConfig {
  static const String _baseServer = "192.168.1.9:8080";

  static const String baseUrl = "http://${ApiConfig._baseServer}";

  static const String wsUrl = "ws://${ApiConfig._baseServer}";
}
