import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

http.Client criarClienteAdmin() => BrowserClient()..withCredentials = true;
const cookiesManuais = false;
