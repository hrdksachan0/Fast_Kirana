"""Independent review probes: fake ORM/cache only; no live SQL or services."""
import asyncio
import ast
import hashlib
import json
import os
import socket
import sys
from pathlib import Path
from types import ModuleType, SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / 'fastapi-backend'
sys.path.insert(0, str(BACKEND))
sys.dont_write_bytecode = True
import dotenv
dotenv.load_dotenv = lambda *a, **kw: False
os.environ.update(DATABASE_URL='sqlite+aiosqlite:///:memory:', AUTH_SECRET='ci_test_auth_secret_key_32chars_long_000', INTERNAL_API_SECRET='ci_test_secret_32chars_long_key_00', CASHFREE_ENV='TEST', APP_ENV='test', REDIS_URL='', SENTRY_DSN='', CASHFREE_APP_ID='', CASHFREE_SECRET_KEY='', SUPABASE_SERVICE_ROLE_KEY='')
original_connect = socket.socket.connect
original_connect_ex = socket.socket.connect_ex
def guarded_connect(sock, address):
    if isinstance(address, tuple) and str(address[0]) not in ('127.0.0.1', '::1', 'localhost'):
        raise RuntimeError('External network disabled in independent review probes')
    return original_connect(sock, address)
def guarded_connect_ex(sock, address):
    if isinstance(address, tuple) and str(address[0]) not in ('127.0.0.1', '::1', 'localhost'):
        raise RuntimeError('External network disabled in independent review probes')
    return original_connect_ex(sock, address)
socket.socket.connect = guarded_connect
socket.socket.connect_ex = guarded_connect_ex

from fastapi import HTTPException
from sqlalchemy.sql import operators
from sqlalchemy.sql.elements import BindParameter, BooleanClauseList, Grouping, Null, True_, False_
from routers import cashfree_router as cr
import models
import utils.cache as cache

async def noop(*args, **kwargs):
    return None
def discard_task(coroutine):
    coroutine.close()
    return None
cr.asyncio = SimpleNamespace(create_task=discard_task)
stub_orders = ModuleType('routers.orders')
stub_orders.send_whatsapp_alert = noop
sys.modules['routers.orders'] = stub_orders

def value(expr, row):
    if isinstance(expr, BindParameter):
        return expr.value
    if isinstance(expr, Null):
        return None
    if isinstance(expr, True_):
        return True
    if isinstance(expr, False_):
        return False
    return getattr(row, expr.key)

def matches(expr, row):
    if isinstance(expr, Grouping):
        return matches(expr.element, row)
    if isinstance(expr, BooleanClauseList):
        found = [matches(x, row) for x in expr.clauses]
        return any(found) if expr.operator is operators.or_ else all(found)
    left, right = value(expr.left, row), value(expr.right, row)
    if expr.operator is operators.in_op:
        return left in right
    if expr.operator is operators.is_:
        return left is right
    if expr.operator is operators.is_not:
        return left is not right
    return bool(expr.operator(left, right))

class Result:
    def __init__(self, rows): self.rows = rows
    def scalars(self): return self
    def all(self): return list(self.rows)
    def first(self): return self.rows[0] if self.rows else None
    def scalar(self): return self.first()
    def scalar_one_or_none(self): return self.first()

class FakeDB:
    def __init__(self, rows):
        self.rows = list(rows)
        self.deleted = []
        self.locks = []
        self.commits = self.rollbacks = 0
    async def execute(self, statement, *args, **kwargs):
        if getattr(statement, '__visit_name__', '') == 'delete':
            entity = statement.entity_description['entity']
            found = [r for r in self.rows if isinstance(r, entity)]
            for condition in statement._where_criteria:
                found = [r for r in found if matches(condition, r)]
            for row in found: await self.delete(row)
            return Result([])
        if not hasattr(statement, 'column_descriptions'):
            if 'nextval' in str(statement): return Result([1234])
            raise AssertionError('Unexpected SQL in review probe: ' + str(statement))
        entity = statement.column_descriptions[0]['entity']
        if entity is None: raise AssertionError('Unexpected non-entity SELECT')
        self.locks.append({'entity': entity.__name__, 'for_update': statement._for_update_arg is not None})
        found = [r for r in self.rows if isinstance(r, entity)]
        for condition in statement._where_criteria:
            found = [r for r in found if matches(condition, r)]
        return Result(found)
    def add(self, row):
        if not any(x is row for x in self.rows): self.rows.append(row)
    async def merge(self, row):
        self.rows = [x for x in self.rows if not (isinstance(x, type(row)) and x.key == row.key)]
        self.rows.append(row)
        return row
    async def delete(self, row):
        self.deleted.append(row)
        self.rows = [x for x in self.rows if x is not row]
    async def flush(self): pass
    async def commit(self): self.commits += 1
    async def rollback(self): self.rollbacks += 1

def setup(*, stock=2, hub_stock=2, variants=None, coupon=None, cart_rows=None):
    user = models.User(id='review-user', name='Review', phone='9999999991', role='USER')
    address = models.Address(id='review-address', userId=user.id, phone=user.phone, lat=26.1, lng=80.1)
    product = models.Product(id='review-product', name='Review item', price=100.0, stock=stock, unit='unit', restaurantId=None, variants=variants)
    hub = models.StoreInventory(productId=product.id, storeId='review-hub', stock=hub_stock)
    rows = [user, address, product, hub]
    if coupon is not None: rows.append(coupon)
    if cart_rows is not None:
        rows.append(models.Cart(id='review-cart', userId=user.id))
        for row_id, variant, quantity in cart_rows:
            rows.append(models.CartItem(id=row_id, cartId='review-cart', productId=product.id, selectedVariant=variant, quantity=quantity))
    db = FakeDB(rows)
    cache_rows = {}
    async def get_cache(key): return cache_rows.get(key)
    async def set_cache(key, data, **kwargs): cache_rows[key] = data
    cache.get_cache, cache.set_cache = get_cache, set_cache
    return db, product, hub, cache_rows

def item(quantity=1, variant=None):
    return {'productId': 'review-product', 'quantity': quantity, 'selectedVariant': variant}

async def quote_and_recover(name, *, rows=None, amount=100.0, delivery='PICKUP', extra=None, setup_options=None, mutate=None):
    db, product, hub, cached = setup(**(setup_options or {}))
    req_data = dict(orderId='review-' + name, items=rows or [item()], amount=amount, customerPhone='9999999991', userId='review-user', addressId='review-address', deliveryMethod=delivery, storeId='review-hub')
    req_data.update(extra or {})
    try:
        response = await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(**req_data), db)
    except HTTPException as exc:
        result = {'case': name, 'http_status': exc.status_code, 'detail': exc.detail, 'rejected': True}
        print(json.dumps(result), flush=True)
        return result
    saved = next(r.response for r in db.rows if isinstance(r, models.IdempotencyRecord))
    if mutate is not None: mutate(db, product, hub)
    recovered = await cr.auto_recover_unplaced_cashfree_order(response['cfOrderId'], response['orderId'], 'review-payment', {'order_amount':response['orderAmount'], 'customer_details':{'customer_phone':'9999999991'}}, {'payment_amount':response['orderAmount']}, db)
    assert recovered is not None, name + ': recovery returned None'
    result = {'case': name, 'quote_amount':response['orderAmount'], 'validated_quote':saved.get('validated_quote'), 'status':str(recovered.status.value if hasattr(recovered.status, 'value') else recovered.status), 'subtotal':recovered.subtotal, 'discount':recovered.discount, 'deliveryFee':recovered.deliveryFee, 'miscFee':recovered.miscFee, 'total':recovered.total, 'stock':product.stock, 'hub_stock':hub.stock, 'cart': [{'id':x.id,'variant':x.selectedVariant,'quantity':x.quantity} for x in db.rows if isinstance(x, models.CartItem)], 'deleted_cart_ids':[x.id for x in db.deleted], 'locks':db.locks}
    print(json.dumps(result), flush=True)
    return result

async def main():
    results = []
    for qty in [-1, 0, 0.5, 1.5, float('nan'), float('inf'), 1001]:
        db, *_ = setup()
        try:
            await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(orderId='invalid-qty', items=[item(qty)], amount=1.0), db)
            result = {'case':'invalid_quantity','quantity':str(qty),'http_status':'accepted'}
        except HTTPException as exc:
            result = {'case':'invalid_quantity','quantity':str(qty),'http_status':exc.status_code}
        results.append(result)
        print(json.dumps(result), flush=True)
    variants = [{'name':'Small','price':100.0,'stock':2}]
    results.append(await quote_and_recover('variant-zero-hub', rows=[item(1,'Small')], setup_options={'variants':variants, 'hub_stock':0}))
    results.append(await quote_and_recover('mixed-variants-hub-one', rows=[item(1,'Small'),item(1,'Large')], amount=200.0, setup_options={'variants':[{'name':'Small','price':100.,'stock':1},{'name':'Large','price':100.,'stock':1}], 'hub_stock':1}))
    coupon = models.Coupon(id='review-coupon', code='SAVE20', discountType='FLAT', value=20., isActive=True, minOrder=0., maxUses=None, usedCount=0, expiresAt=None, maxDiscount=None, oncePerCustomer=False)
    results.append(await quote_and_recover('valid-coupon', amount=80., extra={'couponCode':'SAVE20'}, setup_options={'coupon':coupon}))
    restricted_coupon = models.Coupon(id='restricted-coupon', code='OTHER20', discountType='FLAT', value=20., isActive=True, minOrder=0., maxUses=None, usedCount=0, expiresAt=None, maxDiscount=None, oncePerCustomer=False, categoryId='unrelated-category')
    results.append(await quote_and_recover('ineligible-category-coupon', amount=80., extra={'couponCode':'OTHER20'}, setup_options={'coupon':restricted_coupon}))
    def legacy_invalid_quantity(db, product, hub):
        for row in db.rows:
            if isinstance(row, models.IdempotencyRecord): row.response['items'][0]['quantity'] = -1
    results.append(await quote_and_recover('legacy-negative-quantity', mutate=legacy_invalid_quantity))
    results.append(await quote_and_recover('delivery-defaults', amount=100., delivery='DELIVERY'))
    results.append(await quote_and_recover('pickup-packaging-five', amount=100., extra={'packagingFee':5.}))
    results.append(await quote_and_recover('delivery-zero-client-fees', amount=100., delivery='DELIVERY', extra={'deliveryFee':0.,'packagingFee':0.}))
    results.append(await quote_and_recover('delivery-negative-client-fee', amount=1., delivery='DELIVERY', extra={'deliveryFee':-99.,'packagingFee':0.}))
    results.append(await quote_and_recover('default-cleanup-other-variants', setup_options={'cart_rows':[('default',None,1),('small','Small',3),('large','Large',4)]}))
    def replace_cart_row(db, product, hub):
        db.rows = [r for r in db.rows if not isinstance(r, models.CartItem)]
        db.rows.append(models.CartItem(id='new-default', cartId='review-cart', productId=product.id, selectedVariant=None, quantity=1))
    results.append(await quote_and_recover('replacement-default-cleanup', setup_options={'cart_rows':[('old-default',None,1)]}, mutate=replace_cart_row))
    results.append(await quote_and_recover('accepted-quote-price-changed', amount=100., mutate=lambda db,p,h:setattr(p,'price',120.)))
    from routers import fcm
    victim = models.User(id='victim-user', phone='9999999998', role='USER')
    existing_token = models.FcmToken(id='victim-token', userId=victim.id, token='victim-existing-device', deviceType='android')
    db = FakeDB([victim, existing_token])
    registered = await fcm.register_fcm_token({'userId':victim.id,'token':'attacker-device-token','deviceType':'android'}, current_user=None, db=db)
    result = {'case':'unauthenticated-fcm-victim-binding', 'response':registered, 'remaining_tokens':[{'userId':x.userId,'token':x.token} for x in db.rows if isinstance(x,models.FcmToken)], 'deleted_token_ids':[x.id for x in db.deleted]}
    results.append(result)
    print(json.dumps(result), flush=True)

    from routers import websockets
    other_order = models.Order(id='victim-order', readableId='FK-VICTIM', userId='victim-user', status=models.OrderStatus.CONFIRMED, paymentStatus=models.PaymentStatus.PAID, deliveryMethod='DELIVERY')
    db = FakeDB([other_order])
    class AnonymousRequest:
        async def is_disconnected(self): return False
    try:
        stream = await websockets.sse_single_order_stream(AnonymousRequest(), other_order.id, db)
        connected = await anext(stream.body_iterator)
        status_event = await anext(stream.body_iterator)
        await stream.body_iterator.aclose()
        result = {'case':'unauthenticated-other-order-sse', 'connected':connected.strip(), 'status_event':status_event.strip(), 'rejected':False}
    except HTTPException as exc:
        result = {'case':'unauthenticated-other-order-sse', 'status_code':exc.status_code, 'detail':exc.detail, 'rejected':True}
    results.append(result)
    print(json.dumps(result), flush=True)

    # Execute the exact new checkout stock-deduction block with fake Redis and ORM.
    # The surrounding checkout exception handler was also inspected: no reservation
    # release call occurs anywhere in orders.py.
    source = (BACKEND/'routers/orders.py').read_text(encoding='utf-8')
    tree = ast.parse(source)
    stock_node = next(node for node in ast.walk(tree) if isinstance(node,ast.If) and 'not prod.restaurantId' in ast.unparse(node.test) and 'spec[' in ast.unparse(node.test))
    wrapper = ast.AsyncFunctionDef(name='checkout_stock_block', args=ast.arguments(posonlyargs=[], args=[], kwonlyargs=[], kw_defaults=[], defaults=[]), body=stock_node.body, decorator_list=[])
    module = ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    db, product, hub, _ = setup(stock=2,hub_stock=0)
    redis_stock = {}
    class FakeRedis:
        async def eval(self, script, number_keys, key, qty, seed=None):
            if script == cache._ATOMIC_RELEASE_STOCK_LUA:
                redis_stock[key] = redis_stock.get(key, 0) + int(qty)
                return redis_stock[key]
            assert script == cache._ATOMIC_RESERVE_STOCK_LUA
            current = redis_stock.setdefault(key,int(seed))
            if current < int(qty): return -1
            redis_stock[key] -= int(qty)
            return redis_stock[key]
    async def fake_redis_connection(): return FakeRedis()
    cache.get_redis_connection = fake_redis_connection
    namespace = dict(cr.__dict__)
    namespace.update(db=db,prod=product,item={'quantity':1},spec={'type':models.OrderType.GROCERY},var_name=None,store_id='review-hub',generate_id=lambda prefix:'review-stock-log')
    exec(compile(module,str(BACKEND/'routers/orders.py'),'exec'),namespace)
    try:
        await namespace['checkout_stock_block']()
        outcome='accepted'
    except HTTPException as exc:
        outcome=exc.status_code
        await db.rollback()
        # Simulate transactional SQL rollback; Redis is outside that transaction.
        product.stock=2
        hub.stock=0
    result={'case':'redis-reservation-after-db-rejection','scope':'exact checkout stock source block, fake Redis/ORM; simulated SQL rollback','http_status':outcome,'database_stock_after_rollback':product.stock,'redis_stock_after_rollback':redis_stock,'release_function_called_in_orders_source':'release_reserved_inventory' in source}
    results.append(result)
    print(json.dumps(result),flush=True)

    firebase_tree=ast.parse((BACKEND/'utils/firebase.py').read_text(encoding='utf-8'))
    fallback_node=next((node for node in ast.walk(firebase_tree) if isinstance(node,ast.Assign) and any(isinstance(target,ast.Name) and target.id=='FALLBACK_CREDENTIALS' for target in node.targets)), None)
    if fallback_node:
        fallback=ast.literal_eval(fallback_node.value)
        from cryptography.hazmat.primitives.serialization import load_pem_private_key
        private_key=load_pem_private_key(fallback['private_key'].encode(),password=None)
        result={'case':'tracked-firebase-fallback-private-key','parses_as_private_key':True,'key_bits':private_key.key_size,'live_validity_checked':False}
    else:
        result={'case':'tracked-firebase-fallback-private-key','fallback_credentials_present':False,'remediated':True}
    results.append(result)
    print(json.dumps(result),flush=True)

    output = {'scope':'current complete quote, intent saver, recovery, FCM registration and SSE functions; fake ORM/cache; external network blocked; no actual SQL or alerts', 'source_hash':hashlib.sha256((BACKEND/'routers/cashfree_router.py').read_bytes()).hexdigest(), 'results':results}
    (ROOT/'docs/verification/2026-10-16-r2-probes.json').write_text(json.dumps(output,indent=2),encoding='utf-8')

asyncio.run(main())
