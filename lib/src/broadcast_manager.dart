/// 广播接收回调
typedef BroadcastReceiver = void Function();

/// 广播数据接收回调包装器
class _ReceiverWrapper {
	_ReceiverWrapper(this.receiver, this.isRecvAll);
	
	/// 是否允许接收存在数据的广播
	final bool isRecvAll;
	
	/// 广播数据接收回调
	final BroadcastReceiver receiver;
}

/// 广播数据接收回调
typedef BroadcastDataReceiver<T> = void Function(T dataObj);

/// 广播数据接收回调包装器
class _DataReceiverWrapper<T> {
	_DataReceiverWrapper(this.receiver, this.isAllowNull);
	
	/// 数据类型
	final Type type = T;
	
	/// 是否允许数据为 null 时触发回调
	final bool isAllowNull;
	
	/// 广播数据接收回调
	final BroadcastDataReceiver<T> receiver;
}

/// 广播路由节点
class _BroadcastNode {
	_BroadcastNode prevNode;
	_BroadcastNode nextNode;
	_BroadcastDispatcher dispatcher;
	dynamic key;
	dynamic callback;
	
	@override
	bool operator ==(other) {
		return other is _BroadcastNode && other.callback == callback;
	}
	
	@override
	int get hashCode => callback.hashCode;
}

/// 广播分发器
class _BroadcastDispatcher {
	
	_BroadcastDispatcher(this.key);
	
	final String key;
	
	/// 根广播节点
	_BroadcastNode rootNode;
	
	
	/// 分发广播
	void dispatch(dynamic data) {
		var node = rootNode;
		while (node != null) {
			if (node.callback is _ReceiverWrapper) {
				final wrapper = node.callback;
				if (wrapper.isRecvAll || data == null) {
					wrapper.receiver();
				}
			}
			else if (node.callback is _DataReceiverWrapper) {
				final wrapper = node.callback;
				
				if (data == null) {
					if (wrapper.isAllowNull) {
						node.callback.receiver(data);
					}
				}
				else if (wrapper.type == data.runtimeType) {
					node.callback.receiver(data);
				}
			}
			node = node.nextNode;
		}
	}
}

typedef BroadcastBuilderCallback = void Function(BroadcastBuilder);

/// 广播构造器
class BroadcastBuilder {
	BroadcastBuilder._(this._source, this._manager);
	
	final dynamic _source;
	final BroadcastManager _manager;
	
	/// 注册广播接收器
	void registerReceiver(
		{dynamic key, bool isRecvAll = true, BroadcastReceiver receiver}) {
		_manager.registerReceiver(
			source: _source, key: key, isRecvAll: isRecvAll, receiver: receiver);
	}
	
	/// 注册广播数据接收器
	void registerDataReceiver<T>(
		{dynamic key, bool isAllowNull = true, BroadcastDataReceiver<
			T> receiver}) {
		_manager.registerDataReceiver<T>(
			source: _source,
			key: key,
			isAllowNull: isAllowNull,
			receiver: receiver);
	}
}

/// 广播管理器
class BroadcastManager {
	static BroadcastManager _rootBroadcastManager;
	
	static BroadcastManager getRootBroadcastManager() =>
		_rootBroadcastManager ??= BroadcastManager();
	
	static final _noneObj = Object();
	
	/// 广播路由表
	final Map<dynamic, _BroadcastDispatcher> _keyReceiverRouteMap = {};
	
	/// 广播引用表
	final Map<dynamic, Set<_BroadcastNode>> _objRefMap = {};
	
	/// 内部添加广播接收器的方法
	void _addReceiver(dynamic source, dynamic key, dynamic receiver) {
		source ??= _noneObj;
		var objSet = _objRefMap[source];
		if (objSet == null) {
			objSet = {};
			_objRefMap[source] = objSet;
		}
		
		final node = _BroadcastNode();
		node.key = key;
		node.callback = receiver;
		
		if (objSet.add(node)) {
			var dispatcher = _keyReceiverRouteMap[key];
			if (dispatcher == null) {
				dispatcher = _BroadcastDispatcher(key);
				_keyReceiverRouteMap[key] = dispatcher;
			}
			
			node.dispatcher = dispatcher;
			if (dispatcher.rootNode != null) {
				dispatcher.rootNode.prevNode = node;
				node.nextNode = dispatcher.rootNode;
				dispatcher.rootNode = node;
			}
			else {
				dispatcher.rootNode = node;
			}
		}
	}
	
	/// 移除广播路由节点
	void _removeNode(_BroadcastNode node) {
		final prevNode = node.prevNode;
		final nextNode = node.nextNode;
		if (prevNode == null && nextNode == null) {
			_keyReceiverRouteMap.remove(node.dispatcher.key);
			return;
		}
		
		if (prevNode != null) {
			prevNode.nextNode = nextNode;
		}
		
		if (nextNode != null) {
			nextNode.prevNode = prevNode;
		}
	}
	
	/// 注册广播接收器
	void registerReceiver(
		{dynamic source, dynamic key, bool isRecvAll = true, BroadcastReceiver receiver}) {
		if (key != null && receiver != null) {
			_addReceiver(
				source, key, _ReceiverWrapper(receiver, isRecvAll ?? true));
		}
	}
	
	/// 注册广播数据接收器
	void registerDataReceiver<T>(
		{dynamic source, dynamic key, bool isAllowNull = true, BroadcastDataReceiver<
			T> receiver}) {
		if (key != null && receiver != null) {
			_addReceiver(
				source, key,
				_DataReceiverWrapper(receiver, isAllowNull ?? true));
		}
	}
	
	/// 使用广播构造器注册广播接收器
	void registerWithBuilder(
		{dynamic source, BroadcastBuilderCallback callback}) {
		if (callback != null) {
			final builder = BroadcastBuilder._(source, this);
			callback(builder);
		}
	}
	
	/// 注销指定对象、指定 key 广播接收器
	void unregisterReceiver(dynamic source, dynamic key) {
		source ??= _noneObj;
		final nodeSet = _objRefMap[source];
		if (nodeSet == null) {
			return;
		}
		
		nodeSet.removeWhere((node) {
			final isDel = node.key == key;
			if (isDel) {
				_removeNode(node);
			}
			return isDel;
		});
		
		if (nodeSet.isEmpty) {
			_objRefMap.remove(source);
		}
	}
	
	/// 注销指定对象的全部广播接收器
	void unregisterObjectAllReceiver(dynamic source) {
		source ??= _noneObj;
		final nodeSet = _objRefMap[source];
		if (nodeSet == null) {
			return;
		}
		
		nodeSet.forEach((node) {
			_removeNode(node);
		});
		_objRefMap.remove(source);
	}
	
	/// 注销指全部广播接收器
	void unregisterAllReceiver() {
		_objRefMap.clear();
		_keyReceiverRouteMap.clear();
	}
	
	/// 分发广播
	void dispatch({dynamic key, dynamic data}) {
		final dispatcher = _keyReceiverRouteMap[key];
		if (dispatcher != null) {
			dispatcher.dispatch(data);
		}
	}
}