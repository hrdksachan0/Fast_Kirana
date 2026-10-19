"""Actual ASGI cart requests and isolated SQLite; external networking disabled."""
import ast
from pathlib import Path
_runner=Path(__file__).with_name('run_python_recheck_2026_10_19.py')
_tree=ast.parse(_runner.read_text(encoding='utf-8-sig'))
_prefix=[]
for _node in _tree.body:
    if isinstance(_node,ast.Import) and any(a.name=='pytest' for a in _node.names): break
    _prefix.append(_node)
exec(compile(ast.Module(body=_prefix,type_ignores=[]),str(_runner),'exec'),globals())
os.environ['TESTING']='1'
import asyncio
from httpx import ASGITransport,AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker
from sqlalchemy import select
from database import Base,get_db
from fastapi import FastAPI
from routers import cart
app=FastAPI()
app.include_router(cart.router,prefix='/api')
import models

async def noop(*args,**kwargs): pass
cart.broadcast_cart_update=noop
results=[]
def record(**row):
    results.append(row)
    print(json.dumps(row),flush=True)

async def main():
    engine=create_async_engine('sqlite+aiosqlite:///:memory:')
    async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
    factory=async_sessionmaker(engine,expire_on_commit=False)
    async def override_db():
        async with factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
    app.dependency_overrides[get_db]=override_db
    async with factory() as session:
        session.add(models.User(id='review-victim',phone='9999999991',role='USER',name='Victim',isBlocked=False))
        session.add(models.Product(id='prod_1',slug='review-product',name='Premium product',price=100.,mrp=100.,stock=10,unit='unit',variants=[{'name':'Small','price':100.,'stock':10}]))
        session.add(models.Product(id='prod',slug='review-short-product',name='Different product',price=1.,mrp=1.,stock=10,unit='unit',variants=[{'name':'Small','price':1.,'stock':10}]))
        session.add(models.Cart(id='review-cart',userId='review-victim'))
        session.add(models.CartItem(id='review-line',cartId='review-cart',productId='prod_1',quantity=3,selectedVariant='Small'))
        await session.commit()
    async with AsyncClient(transport=ASGITransport(app=app),base_url='http://localhost') as client:
        response=await client.get('/api/cart')
        record(case='anonymous-no-phone-control',http_status=response.status_code,count=response.json().get('count'))
        response=await client.get('/api/cart',headers={'x-user-phone':'9999999991'})
        record(case='anonymous-victim-phone-read',http_status=response.status_code,cartId=response.json().get('cartId'),items=[dict(productId=i['productId'],quantity=i['quantity']) for i in response.json().get('items',[])])
        response=await client.post('/api/cart',json={'userPhone':'9999999991','storeId':'review-other-store','items':[]})
        async with factory() as session:
            victim=(await session.execute(select(models.User).where(models.User.id=='review-victim'))).scalars().first()
            rows=(await session.execute(select(models.CartItem).where(models.CartItem.cartId=='review-cart'))).scalars().all()
            record(case='anonymous-victim-phone-write',http_status=response.status_code,remaining_items=len(rows),assignedStoreId=victim.assignedStoreId)
        # A separate guest session exercises the newly introduced encoded-ID resolver.
        response=await client.post('/api/cart',headers={'x-guest-id':'review-new-guest'},json={'items':[{'productId':'prod_1_Small','selectedVariant':'Small','quantity':1}]})
        loaded=await client.get('/api/cart',headers={'x-guest-id':'review-new-guest'})
        record(case='encoded-cart-overlapping-product',http_status=response.status_code,items=[dict(productId=i['productId'],variant=i['selectedVariant'],quantity=i['quantity']) for i in loaded.json().get('items',[])])
        response=await client.post('/api/cart',headers={'x-guest-id':'review-new-guest'},json={'items':[{'productId':'prod_1','selectedVariant':'Small','quantity':1}]})
        loaded=await client.get('/api/cart',headers={'x-guest-id':'review-new-guest'})
        record(case='exact-cart-product-control',http_status=response.status_code,items=[dict(productId=i['productId'],variant=i['selectedVariant'],quantity=i['quantity']) for i in loaded.json().get('items',[])])
    await engine.dispose()
    (BACKEND.parent/'docs/verification/2026-10-19-cart-security-route.json').write_text(json.dumps(dict(scope='actual ASGI requests, actual isolated SQLite; no auth/internal secret sent; cart broadcasts suppressed; external network blocked',results=results),indent=2),encoding='utf-8')

asyncio.run(main())

