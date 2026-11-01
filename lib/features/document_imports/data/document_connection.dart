import 'package:connectivity_plus/connectivity_plus.dart';

class DocumentConnection {
  Future<bool> hasNetwork() async =>
      !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
}
