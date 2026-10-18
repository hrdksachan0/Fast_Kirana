"""Offline R3 recheck. Application source is read, never modified."""
import ast
import re
from pathlib import Path

library = Path(__file__).with_name('recheck_2026_10_17_r2.py')
tree = ast.parse(library.read_text(encoding='utf-8'))
prefix = []
for node in tree.body:
    if isinstance(node, ast.AsyncFunctionDef) and node.name == 'main': break
    prefix.append(node)
exec(compile(ast.Module(body=prefix, type_ignores=[]), str(library), 'exec'), globals())

async def main():
    await checkout('eligible-category-coupon', items=[dict(item(),price=1000.)], amount=1., extra={'couponCode':'ELIGIBLE20'}, setup_options={'coupon':coupon('ELIGIBLE20','PERCENT','eligible-cat')}, prepare=lambda db,p,hub:setattr(p,'categoryId','eligible-cat'))
    await checkout('forged-category', items=[dict(item(),price=1000.,categoryId='other-cat')], amount=1., extra={'couponCode':'CAT20'}, setup_options={'coupon':coupon('CAT20','PERCENT','other-cat')})
    await checkout('accepted-price-after-catalog-change', mutate=lambda db,p,hub:setattr(p,'price',120.))
    await checkout('client-line-price', items=[dict(item(),price=1.)])
    await checkout('encoded-variant-client-price', items=[{'productId':'review-product_Small','quantity':1,'selectedVariant':'Small','price':1.}], amount=1., setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]})
    await checkout('unknown-product', items=[{'productId':'nonexistent','quantity':1,'price':1.}], amount=1.)
    await checkout('invalid-variant', items=[dict(item(),selectedVariant='Unknown')], setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]})
    await checkout('duplicate-lines-last-unit-pending-intent', items=[item(),item()], amount=200., setup_options={'stock':1,'hub_stock':1})

    def overlapping_ids(db,p,hub):
        p.id = 'prod_1'
        hub.productId = p.id
        db.add(models.Product(id='prod', name='Different cheap product', price=1., stock=2, variants=[{'name':'Small','price':1.,'stock':2}]))
    await checkout('encoded-overlapping-product-ids', items=[{'productId':'prod_1_Small','quantity':1,'selectedVariant':'Small','price':100.}], amount=1., setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]}, prepare=overlapping_ids)
    await checkout('exact-overlapping-product-id-control', items=[{'productId':'prod_1','quantity':1,'selectedVariant':'Small','price':100.}], setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]}, prepare=overlapping_ids)

    from routers import websockets
    victim=models.User(id='victim-user',role='USER',isBlocked=False)
    rider=models.User(id='rider-user',role='DELIVERY',isBlocked=False)
    blocked=models.User(id='blocked-user',role='USER',isBlocked=True)
    demoted=models.User(id='demoted-user',role='USER',isBlocked=False)
    administrator=models.User(id='admin-enum',role=models.Role.ADMIN,isBlocked=False)
    order=models.Order(id='victim-order',readableId='FK-VICTIM',userId=victim.id,deliveryUserId=rider.id,status=models.OrderStatus.ADMIN_PENDING,paymentStatus=models.PaymentStatus.PAID,deliveryMethod='DELIVERY')
    db=FakeDB([victim,rider,blocked,demoted,administrator,order])
    from utils.jwt import create_access_token
    class Request:
        headers={}
        query_params={}
        async def is_disconnected(self): return False
    cases=[('owner',{'id':victim.id,'role':'USER'},None),('rider',{'id':rider.id,'role':'DELIVERY'},None),('blocked-token',None,create_access_token({'id':blocked.id,'role':'ADMIN'})),('demoted-token',None,create_access_token({'id':demoted.id,'role':'ADMIN'})),('admin-enum',{'id':administrator.id,'role':'ADMIN'},None)]
    for name,user,token in cases:
        try:
            stream=await websockets.sse_single_order_stream(Request(),order.id,db,current_user=user,token=token)
            await anext(stream.body_iterator)
            await anext(stream.body_iterator)
            await stream.body_iterator.aclose()
            record(dict(case='sse-'+name,http_status=200))
        except HTTPException as exc: record(dict(case='sse-'+name,http_status=exc.status_code))

    previous_matches=matches
    def match_with_like(expr,row):
        if getattr(getattr(expr,'operator',None),'__name__','') in ('ilike_op','like_op'):
            left,right=value(expr.left,row),value(expr.right,row)
            if left is None: return False
            pattern='^'+re.escape(str(right)).replace('%','.*').replace('_','.')+'$'
            return re.match(pattern,str(left),re.I) is not None
        return previous_matches(expr,row)
    globals()['matches']=match_with_like
    FakeDB.refresh=noop
    stub_orders.dispatch_isolated_order_fcm_notifications=noop
    stub_orders.dispatch_isolated_status_update_notifications=noop
    websockets.manager.broadcast_to_channel=noop
    from routers import admin_extended
    from fastapi import BackgroundTasks

    db,p,hub,cached=setup()
    quote=await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(orderId='approval-stock',items=[item()],amount=100.,userId='review-user',addressId='review-address',customerPhone='9999999991',deliveryMethod='PICKUP',storeId='review-hub'),db)
    recovered=await cr.auto_recover_unplaced_cashfree_order(quote['cfOrderId'],quote['orderId'],'review-paid',{'order_amount':100.,'customer_details':{'customer_phone':'9999999991'}},{'payment_amount':100.},db)
    for requested in ['CONFIRMED','PACKED','CANCELLED']:
        recovered.status=models.OrderStatus.ADMIN_PENDING
        before=str(recovered.status)
        try:
            approval=await admin_extended.admin_update_order_status(SimpleNamespace(),recovered.id,{'status':requested},{'id':'review-admin','role':'ADMIN'},db,BackgroundTasks())
            record(dict(case='actual-admin-'+requested,returned=approval,before=before,product_stock=p.stock,hub_stock=hub.stock))
        except Exception as exc:
            record(dict(case='actual-admin-'+requested,before=before,error_type=type(exc).__name__,error=str(exc),product_stock=p.stock,hub_stock=hub.stock))
    record(dict(case='status-enum-members',members=list(models.OrderStatus.__members__)))

    # This body is unreachable today because the containing condition raises
    # AttributeError. Execute its exact AST separately to reveal inventory
    # defects that would remain after correcting the enum reference.
    admin_source=(BACKEND/'routers/admin_extended.py').read_text(encoding='utf-8')
    admin_tree=ast.parse(admin_source)
    stock_if=next(n for n in ast.walk(admin_tree) if isinstance(n,ast.If) and 'target_status in' in ast.unparse(n.test) and 'STOCK_DEDUCTED' in ast.unparse(n.test))
    args=ast.arguments(posonlyargs=[],args=[],kwonlyargs=[],kw_defaults=[],defaults=[])
    wrapper=ast.AsyncFunctionDef(name='approval_inventory_body',args=args,body=stock_if.body,decorator_list=[])
    module=ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    for name,quantity,lines in [('single-unit-control',2,1),('duplicate-lines',1,2)]:
        db,p,hub,_=setup(stock=quantity,hub_stock=quantity)
        approval_order=models.Order(id='inventory-order',storeId='review-hub',notes='Paid recovered order')
        db.add(approval_order)
        for idx in range(lines): db.add(models.OrderItem(id=f'line-{idx}',orderId=approval_order.id,productId=p.id,quantity=1,price=100.))
        namespace=dict(admin_extended.__dict__)
        namespace.update(db=db,order=approval_order)
        exec(compile(module,str(BACKEND/'routers/admin_extended.py'),'exec'),namespace)
        try:
            await namespace['approval_inventory_body']()
            record(dict(case='isolated-admin-stock-'+name,scope='exact inventory body; unreachable until enum error fixed',initial_stock=quantity,total_requested=lines,product_stock=p.stock,hub_stock=hub.stock,notes=approval_order.notes,stock_logs=[dict(quantity=r.quantity,newStock=r.newStock) for r in db.rows if isinstance(r,models.StockLog)]))
        except HTTPException as exc: record(dict(case='isolated-admin-stock-'+name,http_status=exc.status_code,detail=exc.detail))

    output=dict(scope='actual functions with fake ORM/cache, plus explicitly isolated unreachable inventory body; no live SQL, gateway or alerts',results=results,hashes={p:hashlib.sha256((BACKEND/p).read_bytes()).hexdigest() for p in ['routers/cashfree_router.py','routers/orders.py','routers/websockets.py','routers/admin_extended.py']})
    (ROOT/'docs/verification/2026-10-17-r3-probes.json').write_text(json.dumps(output,indent=2),encoding='utf-8')

asyncio.run(main())
