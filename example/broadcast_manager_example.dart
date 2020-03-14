
import 'package:broadcast_manager/broadcast_manager.dart';

void main() {
  final manager = BroadcastManager();
  manager.registerWithBuilder(source: null, callback: (builder) {
    builder.registerReceiver(key: 'key1', receiver: () {
      print('recv');
    });
    builder.registerReceiver(key: 'key1', receiver: () {
      print('recv(2)');
    });
    builder.registerReceiver(key: 'key1', isRecvAll: false, receiver: () {
      print('recv(3)');
    });
    builder.registerDataReceiver(key: 'key1', isAllowNull: true, receiver: (String data) {
      print('recv(4), data: $data');
    });
    
    builder.registerDataReceiver(key: 'key2', isAllowNull: false, receiver: (String data) {
      print('recv(5), data: $data');
    });
  });
  final obj = Object();
  manager.registerWithBuilder(source: obj, callback: (builder) {
    builder.registerReceiver(key: 'key1', receiver: () {
      print('obj recv');
    });
  }) ;
  print('=====key1======');
  manager.dispatch(key: 'key1', data: null);
  manager.dispatch(key: 'key1', data: 'hello');
  print('=====key2======');
  manager.dispatch(key: 'key2', data: null);
  manager.dispatch(key: 'key2', data: 'hello');
  
  manager.unregisterReceiver(null, 'key1');
  print('=====key1 again======');
  manager.dispatch(key: 'key1', data: null);
  print('=====key2 again======');
  manager.dispatch(key: 'key2', data: 'hello');
}