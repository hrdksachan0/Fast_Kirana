"""Fresh review of f04f2a81: fake ORM/cache and isolated source-block probes."""
import ast
import re
from pathlib import Path
library=Path(__file__).with_name('recheck_2026_10_17.py')
tree=ast.parse(library.read_text(encoding='utf-8'))
prefix=[]
for node in tree.body:
    if isinstance(node,ast.AsyncFunctionDef) and node.name=='main': break
    prefix.append(node)
exec(compile(ast.Module(body=prefix,type_ignores=[]),str(library),'exec'),globals())

async def main():
    await checkout('old-inflated-price-eligible-category',items=[dict(item(),price=1000.)],amount=1.,extra={'couponCode':'ELIGIBLE20'},setup_options={'coupon':coupon('ELIGIBLE20','PERCENT','eligible-cat')},prepare=lambda db,p,hub:setattr(p,'categoryId','eligible-cat'))
    await checkout('old-forged-category',items=[dict(item(),price=1000.,categoryId='other-cat')],amount=1.,extra={'couponCode':'CAT20'},setup_options={'coupon':coupon('CAT20','PERCENT','other-cat')})
    await checkout('accepted-price-after-catalog-change',mutate=lambda db,p,hub:setattr(p,'price',120.))
    await checkout('old-client-line-price',items=[dict(item(),price=1.)])
    await checkout('encoded-variant-client-price',items=[{'productId':'review-product_Small','quantity':1,'selectedVariant':'Small','price':1.}],amount=1.,setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]})

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
            event=await anext(stream.body_iterator)
            await stream.body_iterator.aclose()
            record(dict(case='sse-'+name,http_status=200))
        except HTTPException as exc: record(dict(case='sse-'+name,http_status=exc.status_code))

    # The current recovery intentionally leaves every paid order ADMIN_PENDING.
    # Inspect its dormant confirmed-order cleanup block without changing app code.
    cashfree_source=(BACKEND/'routers/cashfree_router.py').read_text(encoding='utf-8')
    cashfree_tree=ast.parse(cashfree_source)
    cleanup=next(node for node in ast.walk(cashfree_tree) if isinstance(node,ast.If) and 'user and items_to_create' in ast.unparse(node.test))
    args=ast.arguments(posonlyargs=[],args=[],kwonlyargs=[],kw_defaults=[],defaults=[])
    wrapper=ast.AsyncFunctionDef(name='cleanup_block',args=args,body=cleanup.body,decorator_list=[])
    module=ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    for name,rows,accepted_id in [('other-variants',[('default',None,1),('small','Small',3),('large','Large',4)],'default'),('newer-quantity',[('default',None,3)],'default'),('replacement',[('new-default',None,1)],'old-default')]:
        db,p,hub,_=setup(cart_rows=rows)
        namespace=dict(cr.__dict__)
        namespace.update(db=db,user=next(r for r in db.rows if isinstance(r,models.User)),items_to_create=[dict(item(),cartItemId=accepted_id)],db_products={p.id:p},val_quote={})
        exec(compile(module,str(BACKEND/'routers/cashfree_router.py'),'exec'),namespace)
        await namespace['cleanup_block']()
        record(dict(case='confirmed-cleanup-'+name,scope='exact cleanup source block; current recovery does not enter this branch',cart=[dict(id=r.id,variant=r.selectedVariant,quantity=r.quantity) for r in db.rows if isinstance(r,models.CartItem)],deleted=[r.id for r in db.deleted]))

    # Verify the new commit-aware exception handler with explicit local state.
    source=(BACKEND/'routers/orders.py').read_text(encoding='utf-8')
    tree=ast.parse(source)
    handler=next(node for node in ast.walk(tree) if isinstance(node,ast.ExceptHandler) and node.lineno>2400 and node.name=='e' and 'transaction_committed' in ast.unparse(node))
    args=ast.arguments(posonlyargs=[],args=[ast.arg(arg=x) for x in ['transaction_committed','reserved_redis_items','result_payload']],kwonlyargs=[],kw_defaults=[],defaults=[])
    wrapper=ast.AsyncFunctionDef(name='commit_handler',args=args,body=handler.body,decorator_list=[])
    module=ast.fix_missing_locations(ast.Module(body=[wrapper],type_ignores=[]))
    released=[]
    async def release(key,qty): released.append((key,qty))
    cache.release_reserved_inventory=release
    namespace=dict(cr.__dict__)
    namespace.update(db=FakeDB([]),e=RuntimeError('post-commit publication failure'))
    exec(compile(module,str(BACKEND/'routers/orders.py'),'exec'),namespace)
    result=await namespace['commit_handler'](True,[('stock:review',1)],{'id':'committed-order'})
    record(dict(case='post-commit-reservation',returned=result,released=released))

    # Canonical role representation from the actual isolated ORM round trip.
    from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
    engine=create_async_engine('sqlite+aiosqlite:///:memory:')
    async with engine.begin() as conn: await conn.run_sync(models.User.__table__.create)
    factory=async_sessionmaker(engine,expire_on_commit=False)
    async with factory() as session:
        session.add(models.User(id='orm-admin',role='ADMIN',isBlocked=False))
        await session.commit()
    async with factory() as session:
        loaded=(await session.execute(cr.select(models.User).where(models.User.id=='orm-admin'))).scalars().first()
        record(dict(case='orm-admin-role',python_type=type(loaded.role).__name__,rendered=str(loaded.role),value=loaded.role.value))
    await engine.dispose()

    # Full paid recovery -> actual authorized admin status endpoint, fake ORM only.
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
    before=str(recovered.status)
    approval=await admin_extended.admin_update_order_status(SimpleNamespace(),recovered.id,{'status':'CONFIRMED'},{'id':'review-admin','role':'ADMIN'},db,BackgroundTasks())
    record(dict(case='paid-recovery-admin-approval-stock',before_approval=before,after_approval=approval,ordered_quantity=1,initial_product_stock=2,product_stock=p.stock,hub_stock=hub.stock))
    output=dict(scope='current functions with fake ORM/cache; exact dormant cleanup/exception blocks; one isolated SQLite User round trip; no live SQL, gateway or alerts',results=results,hashes={p:hashlib.sha256((BACKEND/p).read_bytes()).hexdigest() for p in ['routers/cashfree_router.py','routers/orders.py','routers/websockets.py']})
    (ROOT/'docs/verification/2026-10-17-r2-probes.json').write_text(json.dumps(output,indent=2),encoding='utf-8')

asyncio.run(main())
