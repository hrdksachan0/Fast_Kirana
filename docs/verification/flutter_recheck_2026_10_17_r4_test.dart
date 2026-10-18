import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:fastkirana_flutter/core/network/api_client.dart';
import 'package:fastkirana_flutter/data/models/cart.dart';
import 'package:fastkirana_flutter/data/models/product.dart';
import 'package:fastkirana_flutter/data/models/checkout_draft.dart';
import 'package:fastkirana_flutter/data/models/store_hub.dart';
import 'package:fastkirana_flutter/data/models/store_settings.dart';
import 'package:fastkirana_flutter/data/repositories/cart_repository.dart';
import 'package:fastkirana_flutter/features/checkout/controllers/checkout_controller.dart';
import 'package:fastkirana_flutter/providers/cart_provider.dart';
import 'package:fastkirana_flutter/providers/store_hub_provider.dart';
import 'package:fastkirana_flutter/providers/store_settings_provider.dart';

Product product(String id) => Product.fromJson({'id':id,'name':'Review $id','price':100,'mrp':100,'stock':100,'unit':'1 pc'});
CartItem item(String id,{int quantity=1}) => CartItem(id:'item_$id',cartId:'cart_active',productId:id,product:product(id),quantity:quantity);
Future<void> until(bool Function() condition) async {
  for(var n=0;n<500;n++){if(condition())return;await Future<void>.delayed(const Duration(milliseconds:10));}
  throw StateError('review condition timed out');
}
class FailSecondWrite extends InMemorySharedPreferencesStore {
  final bool throws; int writes=0;
  FailSecondWrite(this.throws):super.withData({'flutter.user_phone':'9000000000','flutter.selected_hub_id':'review_hub'});
  @override Future<bool> setValue(String type,String key,Object value) async {
    if(key.contains('accepted_checkout_draft') && ++writes==2){if(throws)throw StateError('injected second write failure');return false;}
    return super.setValue(type,key,value);
  }
}
class DelayedLocal extends CartRepository {
  final captured=Completer<void>();final release=Completer<void>();bool first=true;
  DelayedLocal(super.dio);
  @override Future<List<CartItem>> getLocalCart() async {final rows=await super.getLocalCart();if(first){first=false;captured.complete();await release.future;}return rows;}
}
class DelayedKey extends CartRepository {
  final captured=Completer<void>();final release=Completer<void>();bool first=true;
  DelayedKey(super.dio);
  @override Future<String> getPendingSyncKeyForCurrentScope() async {final key=await super.getPendingSyncKeyForCurrentScope();if(first){first=false;captured.complete();await release.future;}return key;}
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'),(call)async=>null);
  messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global/events'),(call)async=>null);
  messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'),(call)async{
    final args=call.arguments;if(args is Map && args['playerId']!=null){messenger.setMockMethodCallHandler(MethodChannel('xyz.luan/audioplayers/events/${args['playerId']}'),(event)async=>null);}return null;
  });
  for(final throws in [false,true]){
    test('second draft write preserves committed record throws=$throws',() async {
      SharedPreferences.setMockInitialValues({});SharedPreferencesStorePlatform.instance=FailSecondWrite(throws);
      await CheckoutDraft.saveAcceptedDraft(CheckoutDraft(hubId:'review_hub',cfOrderId:'first-accepted',grandTotal:100));
      await expectLater(CheckoutDraft.saveAcceptedDraft(CheckoutDraft(hubId:'review_hub',cfOrderId:'replacement',grandTotal:100)),throwsStateError);
      final prefs=await SharedPreferences.getInstance();await prefs.reload();
      final draft=await CheckoutDraft.loadAcceptedDraft();
      print(jsonEncode({'case':'second-save','throws':throws,'durableDraft':draft?.cfOrderId}));
      expect(draft?.cfOrderId,'first-accepted');
    });
  }
  for(final acknowledgement in ['none','ack','journal']){
    final persistedAck=acknowledgement=='ack';
    final journalOnly=acknowledgement=='journal';
    test('completion with acknowledgement=$acknowledgement',() async {
      final orderId=journalOnly?'journal-only-order':(persistedAck?'persisted-order':'concurrent-order');
      SharedPreferences.setMockInitialValues({'user_id':'review_buyer','user_phone':'9999999999','selected_hub_id':'review_hub',if(persistedAck)'acknowledged_order_ids':[orderId],if(journalOnly)'cart_applied_order_deltas':[orderId]});
      final serverCart=Cart(id:'cart_active',userId:'review_buyer',items:[item('A',quantity:3),item('B')],couponDiscount:0,createdAt:DateTime.now(),updatedAt:DateTime.now());
      var posts=0;final barrier=Completer<void>();
      final dio=Dio(BaseOptions(baseUrl:'http://review.invalid'));
      dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h){
        if(o.method=='POST'&&o.path=='/api/orders'){
          posts++;if(persistedAck||journalOnly||posts==2){if(!barrier.isCompleted)barrier.complete();}
          unawaited(barrier.future.then((_){h.resolve(Response(requestOptions:o,statusCode:200,data:{'id':orderId,'readableId':'FK-REVIEW'}));}));
        }else if(o.path=='/api/cart'&&o.method=='GET'){h.resolve(Response(requestOptions:o,statusCode:200,data:serverCart.toJson()));}
        else if(o.path=='/api/addresses'){h.resolve(Response(requestOptions:o,statusCode:200,data:[]));}
        else if(o.path=='/api/cart'){h.resolve(Response(requestOptions:o,statusCode:200,data:{'success':true}));}
        else {h.reject(DioException(requestOptions:o,error:'External HTTP blocked'));}
      }));
      final container=ProviderContainer(overrides:[dioProvider.overrideWithValue(dio),currentStoreHubProvider.overrideWithValue(const StoreHub(id:'review_hub',name:'Hub',latitude:26.1534185,longitude:80.1714024)),storeSettingsProvider.overrideWith((ref)async=>const StoreSettings(miscFee:7,deliveryFee:25))]);
      final sub=container.listen(checkoutControllerProvider,(_,__){});final cartSub=container.listen(cartProvider,(_,__){});
      await container.read(storeSettingsProvider.future);await until(()=>container.read(cartProvider).value?.items.length==2);
      final controller=container.read(checkoutControllerProvider.notifier);
      final draft=CheckoutDraft(hubId:'review_hub',deliveryMethod:'PICKUP',selectedPayment:'online',isFrozenForPayment:true,cfOrderId:'cf_$orderId',deliveryFee:0,packagingFee:0,grandTotal:100,items:[{'productId':'A','name':'A','price':100.0,'quantity':1,'selectedVariant':'1 pc'}]);
      if(persistedAck||journalOnly){await controller.completeOrderPlacement(null,draft:draft,cart:Cart.empty(),paymentId:'paid');}
      else {await Future.wait([controller.completeOrderPlacement(null,draft:draft,cart:Cart.empty(),paymentId:'paid'),controller.completeOrderPlacement(null,draft:draft,cart:Cart.empty(),paymentId:'paid')]);}
      final quantity=container.read(cartProvider).value!.items.firstWhere((e)=>e.productId=='A').quantity;
      print(jsonEncode({'case':'completion-ack','persistedAck':persistedAck,'journalOnly':journalOnly,'starting':3,'ordered':1,'final':quantity,'expectedCorrect':(persistedAck||journalOnly)?3:2,'posts':posts}));
      // Assert the intended quantity after duplicate completion and restart.
      expect(quantity,(persistedAck||journalOnly)?3:2);
      await pumpEventQueue(times:40);cartSub.close();sub.close();container.dispose();
    });
  }
  for(final clearDuringHydration in [false,true]){
    test('local hydration clear=$clearDuringHydration',() async {
      SharedPreferences.setMockInitialValues({'user_phone':'9999999999','selected_hub_id':'review_hub'});
      var server=<String>[];
      final dio=Dio(BaseOptions(baseUrl:'http://review.invalid'));
      dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h){if(o.method=='POST')server=(o.data['items'] as List).map((e)=>e['productId'].toString()).toList();h.resolve(Response(requestOptions:o,statusCode:200,data:o.method=='GET'?Cart.empty().toJson():{'success':true}));}));
      final repo=DelayedLocal(dio);await repo.saveLocalCart([item('oldA')]);final notifier=CartNotifier(repo);await repo.captured.future;
      if(clearDuringHydration){await notifier.clearCart();}else{notifier.addProduct(product('newB'));}
      await pumpEventQueue(times:30);repo.release.complete();await Future<void>.delayed(const Duration(milliseconds:800));
      print(jsonEncode({'case':'local-hydration','clear':clearDuringHydration,'server':server,'ui':notifier.state.value!.items.map((e)=>e.productId).toList(),'local':(await repo.getLocalCart()).map((e)=>e.productId).toList(),'pending':await repo.hasPendingSync()}));
      if(!clearDuringHydration){expect(notifier.getQuantity('oldA'),1);expect(notifier.getQuantity('newB'),1);}else{expect(notifier.state.value!.items,isEmpty);expect(await repo.getLocalCart(),isEmpty);}
      notifier.dispose();
    });
  }
  test('pending-key await preserves queued revision',() async {
    SharedPreferences.setMockInitialValues({'user_phone':'9999999999','selected_hub_id':'review_hub'});
    var server=<String>[];
    final dio=Dio(BaseOptions(baseUrl:'http://review.invalid'));
    dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h){if(o.method=='POST')server=(o.data['items'] as List).map((e)=>e['productId'].toString()).toList();h.resolve(Response(requestOptions:o,statusCode:200,data:o.method=='GET'?Cart.empty().toJson():{'success':true}));}));
    final repo=DelayedKey(dio);await repo.saveLocalCart([item('oldA')]);await repo.setPendingSync(true);final notifier=CartNotifier(repo);await repo.captured.future;
    notifier.addProduct(product('newB'));await pumpEventQueue(times:30);repo.release.complete();await until(()=>server.isNotEmpty);await Future<void>.delayed(const Duration(milliseconds:450));
    print(jsonEncode({'case':'pending-key-await','server':server,'ui':notifier.state.value!.items.map((e)=>e.productId).toList(),'pending':await repo.hasPendingSync(),'version':notifier.cartVersion,'ack':notifier.lastAcknowledgedVersion}));
    expect(notifier.getQuantity('newB'),1);expect(server,contains('newB'));notifier.dispose();
  });
  test('clear then add during hydration preserves clear generation',() async {
    SharedPreferences.setMockInitialValues({'user_phone':'9999999999','selected_hub_id':'review_hub'});
    var server=<String>[];
    final dio=Dio(BaseOptions(baseUrl:'http://review.invalid'));
    dio.interceptors.add(InterceptorsWrapper(onRequest:(o,h){if(o.method=='POST')server=(o.data['items'] as List).map((e)=>e['productId'].toString()).toList();h.resolve(Response(requestOptions:o,statusCode:200,data:o.method=='GET'?Cart.empty().toJson():{'success':true}));}));
    final repo=DelayedLocal(dio);await repo.saveLocalCart([item('oldA')]);
    final notifier=CartNotifier(repo);await repo.captured.future;
    await notifier.clearCart();notifier.addProduct(product('newB'));
    repo.release.complete();await until(()=>server.contains('newB'));
    await Future<void>.delayed(const Duration(milliseconds:450));
    final ui=notifier.state.value!.items.map((e)=>e.productId).toList();
    final local=(await repo.getLocalCart()).map((e)=>e.productId).toList();
    print(jsonEncode({'case':'clear-then-add-hydration','ui':ui,'local':local,'server':server}));
    expect(ui,['newB']);expect(local,['newB']);expect(server,['newB']);
    notifier.dispose();
  });
}


