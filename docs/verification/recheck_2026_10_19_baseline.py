"""Offline R5: execute current functions against fake ORM, no app edits."""
import ast
import re
from pathlib import Path
from datetime import datetime

_r4_library=Path(__file__).with_name('recheck_2026_10_17_r3.py')
_r4_tree=ast.parse(_r4_library.read_text(encoding='utf-8'))
prefix=[]
for node in _r4_tree.body:
    if isinstance(node,ast.AsyncFunctionDef) and node.name=='main': break
    prefix.append(node)
exec(compile(ast.Module(body=prefix,type_ignores=[]),str(_r4_library),'exec'),globals())

# Retain the old quote/SSE controls, stopping before the obsolete admin probes.
old_main=next(n for n in _r4_tree.body if isinstance(n,ast.AsyncFunctionDef) and n.name=='main')
control_body=[]
for node in old_main.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='previous_matches' for t in node.targets): break
    control_body.append(node)
controls=ast.AsyncFunctionDef(name='quote_sse_controls',args=old_main.args,body=control_body,decorator_list=[])
exec(compile(ast.fix_missing_locations(ast.Module(body=[controls],type_ignores=[])),str(_r4_library),'exec'),globals())

previous_matches=matches
def match_with_like(expr,row):
    if getattr(getattr(expr,'operator',None),'__name__','') in ('ilike_op','like_op'):
        left,right=value(expr.left,row),value(expr.right,row)
        if left is None: return False
        pattern='^'+re.escape(str(right)).replace('%','.*').replace('_','.')+'$'
        return re.match(pattern,str(left),re.I) is not None
    return previous_matches(expr,row)
globals()['matches']=match_with_like

async def refresh(row):
    # ORM defaults normally populate this at flush; fake ORM has no flush hooks.
    if getattr(row,'updatedAt',None) is None: row.updatedAt=datetime(2026,10,17)
FakeDB.refresh=staticmethod(refresh)
stub_orders.dispatch_isolated_order_fcm_notifications=noop
stub_orders.dispatch_isolated_status_update_notifications=noop
from routers import admin_extended,websockets
from fastapi import BackgroundTasks
websockets.manager.broadcast_to_channel=noop

async def transition(db,order,status):
    return await admin_extended.admin_update_order_status(SimpleNamespace(),order.id,{'status':status},{'id':'review-admin','role':'ADMIN'},db,BackgroundTasks())

async def approval(name,*,stock=2,hub_stock=2,variants=None,lines=None,steps=None):
    db,p,hub,_=setup(stock=stock,hub_stock=hub_stock,variants=variants)
    order=models.Order(id='approval-'+name,readableId='FK-'+name,userId='review-user',storeId='review-hub',notes='Paid recovered order',status=models.OrderStatus.ADMIN_PENDING,total=100.,updatedAt=datetime(2026,10,17))
    db.add(order)
    for i,(variant,qty) in enumerate(lines or [(None,1)]): db.add(models.OrderItem(id=f'item-{i}',orderId=order.id,productId=p.id,quantity=qty,price=100.,selectedVariant=variant))
    history=[]
    for status in steps or ['CONFIRMED']:
        try:
            response=await transition(db,order,status)
            history.append(dict(requested=status,response=response,product_stock=p.stock,hub_stock=hub.stock,notes=order.notes,variants=p.variants))
        except HTTPException as exc:
            history.append(dict(requested=status,http_status=exc.status_code,detail=exc.detail,product_stock=p.stock,hub_stock=hub.stock,commits=db.commits))
            break
    record(dict(case='admin-'+name,history=history,locks=db.locks))

async def paid_variant_without_selection():
    db,p,hub,_=setup(variants=[{'name':'Small','price':100.,'stock':2}])
    quote=await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(orderId='variant-without-selection',items=[item()],amount=100.,userId='review-user',addressId='review-address',customerPhone='9999999991',deliveryMethod='PICKUP',storeId='review-hub'),db)
    recovered=await cr.auto_recover_unplaced_cashfree_order(quote['cfOrderId'],quote['orderId'],'review-paid',{'order_amount':100.,'customer_details':{'customer_phone':'9999999991'}},{'payment_amount':100.},db)
    response=await transition(db,recovered,'CONFIRMED')
    assert p.stock == hub.stock == 1
    assert p.variants[0]['stock'] == 1
    assert next(r for r in db.rows if isinstance(r,models.OrderItem)).selectedVariant == 'Small'
    record(dict(case='paid-variant-without-selection',quote=quote['orderAmount'],response=response,ordered_items=[dict(productId=r.productId,selectedVariant=r.selectedVariant,quantity=r.quantity) for r in db.rows if isinstance(r,models.OrderItem)],initial_product_stock=2,product_stock=p.stock,hub_stock=hub.stock,variants=p.variants,notes=recovered.notes))

async def ambiguous_variants():
    def prepare(db,p,hub):
        p.id='prod_1'
        hub.productId=p.id
        db.add(models.Product(id='prod',name='Short prefix',price=1.,stock=2,variants=[{'name':'1_Small','price':1.,'stock':2}]))
    await checkout('truly-ambiguous-encoded-id',items=[{'productId':'prod_1_Small','quantity':1,'price':1.}],amount=1.,setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]},prepare=prepare)
    await checkout('underscore-variant-name',items=[{'productId':'review-product_Small_Pack','quantity':1,'price':1.}],amount=1.,setup_options={'variants':[{'name':'Small_Pack','price':100.,'stock':2}]})

async def sqlite_variant_without_selection():
    from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
    from database import Base
    engine=create_async_engine('sqlite+aiosqlite:///:memory:')
    async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
    factory=async_sessionmaker(engine,expire_on_commit=False)
    async with factory() as session:
        session.add(models.User(id='sqlite-buyer',phone='9999999991',role='USER'))
        session.add(models.Address(id='sqlite-address',userId='sqlite-buyer',label='Home',houseNo='1',street='Test',area='Test',city='Test',pincode='208001',phone='9999999991'))
        session.add(models.DarkStore(id='sqlite-hub',name='Test hub',city='Test',latitude=26.1,longitude=80.1))
        product=models.Product(id='sqlite-product',name='Variant product',slug='sqlite-product',mrp=100.,price=100.,unit='unit',stock=2,variants=[{'name':'Small','price':100.,'stock':2}])
        inv=models.StoreInventory(productId=product.id,storeId='sqlite-hub',stock=2)
        session.add_all([product,inv])
        await session.commit()
        quote=await cr.create_cashfree_order(cr.CashfreeCreateOrderRequest(orderId='sqlite-variant-without-selection',items=[{'productId':product.id,'quantity':1}],amount=100.,userId='sqlite-buyer',addressId='sqlite-address',customerPhone='9999999991',deliveryMethod='PICKUP',storeId='sqlite-hub'),session)
        recovered=await cr.auto_recover_unplaced_cashfree_order(quote['cfOrderId'],quote['orderId'],'sqlite-paid',{'order_amount':100.,'customer_details':{'customer_phone':'9999999991'}},{'payment_amount':100.},session)
        assert recovered is not None
        response=await transition(session,recovered,'CONFIRMED')
        await session.refresh(product)
        await session.refresh(inv)
        assert product.stock == inv.stock == product.variants[0]['stock'] == 1
        persisted_item=(await session.execute(cr.select(models.OrderItem).where(models.OrderItem.orderId==recovered.id))).scalars().first()
        assert persisted_item.selectedVariant == 'Small'
        record(dict(case='sqlite-paid-variant-without-selection',scope='actual isolated in-memory SQLite quote/recovery/admin commit',response=response,quote=quote['orderAmount'],initial_product_stock=2,product_stock=product.stock,hub_stock=inv.stock,variants=product.variants,notes=recovered.notes))
        lifecycle=[]
        for status,expected in [('CONFIRMED',1),('PACKED',1),('CANCELLED',2),('CANCELLED',2)]:
            response=await transition(session,recovered,status)
            await session.refresh(product)
            await session.refresh(inv)
            assert product.stock == inv.stock == product.variants[0]['stock'] == expected
            lifecycle.append(dict(status=status,product_stock=product.stock,variant_stock=product.variants[0]['stock'],hub_stock=inv.stock))
        record(dict(case='sqlite-default-variant-replay-cancellation',selectedVariant=persisted_item.selectedVariant,lifecycle=lifecycle))
    await engine.dispose()

async def main():
    await quote_sse_controls()
    await ambiguous_variants()
    await checkout('default-variant-server-price',items=[item()],amount=1.,setup_options={'variants':[{'name':'Small','price':120.,'stock':2}]})
    await checkout('blank-variant-default',items=[dict(item(),selectedVariant='   ')],amount=1.,setup_options={'variants':[{'name':'Small','price':100.,'stock':2}]})
    await checkout('default-variant-stock-shortage',items=[item(2)],amount=200.,setup_options={'variants':[{'name':'Small','price':100.,'stock':1}]})
    await approval('normal-lifecycle',steps=['CONFIRMED','CONFIRMED','PACKED','CANCELLED','CANCELLED'])
    await approval('preparing-alias',steps=['PREPARING'])
    await approval('duplicate-last-unit',stock=1,hub_stock=1,lines=[(None,1),(None,1)])
    await approval('duplicate-product-pool',stock=1,hub_stock=5,lines=[(None,1),(None,1)])
    variants=[{'name':'Small','price':100.,'stock':2},{'name':'Large','price':100.,'stock':2}]
    await approval('mixed-variant-shared-store',stock=4,hub_stock=1,variants=variants,lines=[('Small',1),('Large',1)])
    await approval('normalized-variant-duplicates',stock=2,hub_stock=5,variants=[{'name':'Small','price':100.,'stock':1}],lines=[('Small',1),(' small ',1)])
    await approval('valid-variant-lifecycle',stock=4,hub_stock=4,variants=variants,lines=[('Small',1),('Large',1)],steps=['CONFIRMED','PACKED','CANCELLED'])
    await approval('legacy-null-variant',variants=[{'name':'Small','price':100.,'stock':2}],steps=['CONFIRMED','PACKED','CANCELLED','CANCELLED'])
    await approval('legacy-blank-variant',variants=[{'name':'Small','price':100.,'stock':2}],lines=[('   ',1)],steps=['CONFIRMED','CANCELLED'])
    await approval('legacy-invalid-variant',variants=[{'name':'Small','price':100.,'stock':2}],lines=[('GhostVariant',1)])
    await approval('default-plus-explicit-duplicate-demand',stock=1,hub_stock=5,variants=[{'name':'Small','price':100.,'stock':1}],lines=[(None,1),('Small',1)])
    await paid_variant_without_selection()
    await sqlite_variant_without_selection()
    output=dict(scope='actual current quote/recovery/SSE/admin functions with fake ORM/cache plus one real isolated SQLite quote/recovery/admin commit; fake ORM refresh timestamp default simulated; tasks/broadcasts suppressed; no production services',results=results,hashes={p:hashlib.sha256((BACKEND/p).read_bytes()).hexdigest() for p in ['routers/cashfree_router.py','routers/orders.py','routers/websockets.py','routers/admin_extended.py']})
    (ROOT/'docs/verification/2026-10-19-baseline-probes.json').write_text(json.dumps(output,indent=2),encoding='utf-8')

asyncio.run(main())


