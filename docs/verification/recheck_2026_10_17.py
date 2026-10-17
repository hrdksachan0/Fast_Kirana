"""Independent 17 October probes. No application edits, live SQL or services."""
import ast
from pathlib import Path

# Reuse the retained fake ORM/cache definitions, never its old main routine.
base = Path(__file__).with_name('backend_recheck_2026_10_16_r2_probes.py')
tree = ast.parse(base.read_text(encoding='utf-8'))
definitions = []
for node in tree.body:
    if isinstance(node, ast.AsyncFunctionDef) and node.name == 'main': break
    definitions.append(node)
exec(compile(ast.Module(body=definitions,type_ignores=[]),str(base),'exec'),globals())

original_execute = FakeDB.execute
async def projected_execute(self, statement, *args, **kwargs):
    result = await original_execute(self,statement,*args,**kwargs)
    if hasattr(statement,'column_descriptions'):
        column = statement.column_descriptions[0]
        if column['expr'] is not column['entity']:
            result.rows = [getattr(row,column['expr'].key) for row in result.rows]
    return result
FakeDB.execute = projected_execute
results = []
def record(result):
    results.append(result)
    print(json.dumps(result),flush=True)

def coupon(code='SAVE20',kind='FLAT',category=None):
    return models.Coupon(id=code,code=code,discountType=kind,value=20.,isActive=True,minOrder=0.,maxUses=None,usedCount=0,expiresAt=None,maxDiscount=None,oncePerCustomer=False,categoryId=category)

async def checkout(name, *, items=None, amount=100., delivery='PICKUP', extra=None, setup_options=None, prepare=None, mutate=None):
    db,p,hub,cached=setup(**(setup_options or {}))
    if prepare: prepare(db,p,hub)
    request=dict(orderId='review-'+name,items=items or [item()],amount=amount,customerPhone='9999999991',userId='review-user',addressId='review-address',deliveryMethod=delivery,storeId='review-hub')
    request.update(extra or {})
    try:
        response=await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(**request),db)
    except HTTPException as exc:
        record(dict(case=name,quote_http_status=exc.status_code,detail=exc.detail))
        return
    accepted=next(r.response for r in db.rows if isinstance(r,models.IdempotencyRecord))
    if mutate: mutate(db,p,hub)
    recovered=await cr.auto_recover_unplaced_cashfree_order(response['cfOrderId'],response['orderId'],'review-paid',{'order_amount':response['orderAmount'],'customer_details':{'customer_phone':'9999999991'}},{'payment_amount':response['orderAmount']},db)
    record(dict(case=name,quote=response['orderAmount'],accepted_quote=accepted.get('validated_quote'),recovered=recovered is not None,status=str(recovered.status) if recovered else None,subtotal=recovered.subtotal if recovered else None,discount=recovered.discount if recovered else None,total=recovered.total if recovered else None,items=[dict(productId=r.productId,price=r.price,quantity=r.quantity) for r in db.rows if isinstance(r,models.OrderItem)],stock=p.stock,hub_stock=hub.stock,cart=[dict(id=r.id,variant=r.selectedVariant,quantity=r.quantity) for r in db.rows if isinstance(r,models.CartItem)],deleted=[r.id for r in db.deleted]))

async def main():
    await checkout('negative-fee',amount=1.,delivery='DELIVERY',extra={'deliveryFee':-99.,'packagingFee':0.})
    await checkout('zero-fees',delivery='DELIVERY',extra={'deliveryFee':0.,'packagingFee':0.})
    await checkout('valid-coupon',amount=80.,extra={'couponCode':'SAVE20'},setup_options={'coupon':coupon()})
    await checkout('wrong-category-control',amount=80.,extra={'couponCode':'OTHER20'},setup_options={'coupon':coupon('OTHER20',category='other-cat')})
    await checkout('forged-price-category-coupon',items=[dict(item(),price=1000.,categoryId='other-cat')],amount=1.,extra={'couponCode':'CAT20'},setup_options={'coupon':coupon('CAT20','PERCENT','other-cat')})
    await checkout('inflated-price-eligible-category',items=[dict(item(),price=1000.)],amount=1.,extra={'couponCode':'ELIGIBLE20'},setup_options={'coupon':coupon('ELIGIBLE20','PERCENT','eligible-cat')},prepare=lambda db,p,hub:setattr(p,'categoryId','eligible-cat'))
    await checkout('variant-zero-hub',items=[item(1,'Small')],setup_options={'variants':[{'name':'Small','price':100.,'stock':2}],'hub_stock':0})
    await checkout('default-and-other-variants',setup_options={'cart_rows':[('default',None,1),('small','Small',3),('large','Large',4)]})
    def add_unordered_product(db,p,hub):
        db.add(models.Product(id='unpaid-B',name='Unpaid B',price=100.,stock=2))
        db.add(models.CartItem(id='unpaid-B-row',cartId='review-cart',productId='unpaid-B',selectedVariant=None,quantity=1))
    await checkout('unrelated-cart-product',setup_options={'cart_rows':[('ordered-A-row',None,1)]},prepare=add_unordered_product)
    def replace(db,p,hub):
        db.rows=[r for r in db.rows if not isinstance(r,models.CartItem)]
        db.rows.append(models.CartItem(id='new-default',cartId='review-cart',productId=p.id,selectedVariant=None,quantity=1))
    await checkout('replacement-row',setup_options={'cart_rows':[('old-default',None,1)]},mutate=replace)
    def increase(db,p,hub):
        for r in db.rows:
            if isinstance(r,models.CartItem): r.quantity=3
    await checkout('newer-same-row-quantity',setup_options={'cart_rows':[('old-default',None,1)]},mutate=increase)
    await checkout('price-change-no-client-price',mutate=lambda db,p,hub:setattr(p,'price',120.))
    await checkout('client-line-price',items=[dict(item(),price=1.)])
    db,p,hub,cached=setup(cart_rows=[('unpaid-current-cart',None,1)])
    recovered=await cr.auto_recover_unplaced_cashfree_order('no-intent','no-intent','review-paid',{'order_amount':100.,'customer_details':{'customer_phone':'9999999991'}},{'payment_amount':100.},db)
    record(dict(case='missing-intent',status=str(recovered.status) if recovered else None,stock=p.stock,cart_ids=[r.id for r in db.rows if isinstance(r,models.CartItem)]))

    from routers import fcm,websockets
    victim=models.User(id='victim-user',phone='9999999998',role='USER')
    old_token=models.FcmToken(id='victim-token',userId=victim.id,token='victim-device',deviceType='android')
    db=FakeDB([victim,old_token])
    registered=await fcm.register_fcm_token({'userId':victim.id,'phone':victim.phone,'token':'attacker-device'},current_user=None,db=db)
    record(dict(case='anonymous-fcm-target-user',bound_user_id=registered['userId'],victim_id=victim.id,victim_tokens=[r.token for r in db.rows if isinstance(r,models.FcmToken) and r.userId==victim.id],deleted=[r.id for r in db.deleted]))

    other_order=models.Order(id='victim-order',readableId='FK-VICTIM',userId=victim.id,status=models.OrderStatus.CONFIRMED,paymentStatus=models.PaymentStatus.PAID,deliveryMethod='DELIVERY',deliveryUserId='rider-user')
    stale=models.User(id='stale-staff',role='USER',isBlocked=True)
    db=FakeDB([other_order,stale])
    from utils.jwt import create_access_token
    stale_token=create_access_token({'id':stale.id,'role':'ADMIN'})
    class Request:
        headers={}
        query_params={}
        async def is_disconnected(self): return False
    for name,user,token in [('anonymous',None,None),('other-customer',{'id':'other-user','role':'USER'},None),('owner',{'id':victim.id,'role':'USER'},None),('assigned-rider',{'id':'rider-user','role':'DELIVERY'},None),('blocked-demoted-admin-query-token',None,stale_token)]:
        try:
            stream=await websockets.sse_single_order_stream(Request(),other_order.id,db,current_user=user,token=token)
            await anext(stream.body_iterator)
            status_event=await anext(stream.body_iterator)
            await stream.body_iterator.aclose()
            record(dict(case='sse-'+name,http_status=200,status_event=status_event.strip()))
        except HTTPException as exc: record(dict(case='sse-'+name,http_status=exc.status_code))

    source=(BACKEND/'routers/orders.py').read_text(encoding='utf-8')
    tree=ast.parse(source)
    stock_node=next(node for node in ast.walk(tree) if isinstance(node,ast.If) and 'not prod.restaurantId' in ast.unparse(node.test) and 'spec[' in ast.unparse(node.test))
    args=ast.arguments(posonlyargs=[],args=[ast.arg(arg='reserved_redis_items')],kwonlyargs=[],kw_defaults=[],defaults=[])
    wrapper=ast.AsyncFunctionDef(name='stock_block',args=args,body=stock_node.body,decorator_list=[])
    module=ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    db,p,hub,_=setup(stock=2,hub_stock=0)
    redis_stock={}
    class Redis:
        async def eval(self,script,number_keys,key,qty,seed=None):
            if script==cache._ATOMIC_RELEASE_STOCK_LUA:
                redis_stock[key]=redis_stock.get(key,0)+int(qty)
                return redis_stock[key]
            current=redis_stock.setdefault(key,int(seed))
            if current<int(qty): return -1
            redis_stock[key]-=int(qty)
            return redis_stock[key]
    async def connection(): return Redis()
    cache.get_redis_connection=connection
    namespace=dict(cr.__dict__)
    namespace.update(db=db,prod=p,item={'quantity':1},spec={'type':models.OrderType.GROCERY},var_name=None,store_id='review-hub',generate_id=lambda prefix:'stock-log')
    exec(compile(module,str(BACKEND/'routers/orders.py'),'exec'),namespace)
    reserved=[]
    try: await namespace['stock_block'](reserved)
    except HTTPException as exc:
        p.stock=2
        record(dict(case='redis-rejected-hub',http_status=exc.status_code,redis_stock=dict(redis_stock),reserved_remaining=reserved,database_stock_after_simulated_rollback=p.stock))
    handler=next(node for node in ast.walk(tree) if isinstance(node,ast.ExceptHandler) and node.lineno>2400 and node.name=='e' and any(isinstance(child,ast.If) and 'reserved_redis_items' in ast.unparse(child.test) for child in node.body))
    wrapper=ast.AsyncFunctionDef(name='post_commit_handler',args=args,body=handler.body,decorator_list=[])
    module=ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    key='stock:review-hub:review-product:base'
    redis_stock[key]=1
    p.stock=hub.stock=1
    namespace.update(e=RuntimeError('post-commit publication failure'))
    exec(compile(module,str(BACKEND/'routers/orders.py'),'exec'),namespace)
    try: await namespace['post_commit_handler']([(key,1)])
    except HTTPException as exc: record(dict(case='redis-post-commit-handler',scope='exact source handler, simulated already committed SQL sale',http_status=exc.status_code,committed_db_stock=p.stock,redis_stock=redis_stock[key]))
    firebase_source=(BACKEND/'utils/firebase.py').read_text(encoding='utf-8')
    record(dict(case='firebase-key',literal_present='BEGIN PRIVATE KEY' in firebase_source,revocation_verified=False))
    paths=['routers/cashfree_router.py','routers/orders.py','routers/fcm.py','routers/websockets.py','utils/firebase.py']
    output=dict(scope='current functions against fake ORM/cache; exact source blocks for Redis; external network blocked; no live SQL, gateway or alerts',results=results,hashes={p:hashlib.sha256((BACKEND/p).read_bytes()).hexdigest() for p in paths})
    (ROOT/'docs/verification/2026-10-17-probes.json').write_text(json.dumps(output,indent=2),encoding='utf-8')

asyncio.run(main())
