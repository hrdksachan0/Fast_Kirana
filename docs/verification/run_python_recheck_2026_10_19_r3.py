"""Offline backend-suite runner for the 17 October independent recheck."""
import hashlib
import json
import os
from pathlib import Path
import socket
import sys
import time

sys.dont_write_bytecode = True
BACKEND = Path(__file__).resolve().parents[2] / 'fastapi-backend'
os.chdir(BACKEND)
sys.path.insert(0, str(BACKEND))
import dotenv
dotenv.load_dotenv = lambda *args, **kwargs: False
os.environ.update(DATABASE_URL='sqlite+aiosqlite:///:memory:', AUTH_SECRET='ci_test_auth_secret_key_32chars_long_000', INTERNAL_API_SECRET='ci_test_secret_32chars_long_key_00', CASHFREE_ENV='TEST', APP_ENV='test', REDIS_URL='', SENTRY_DSN='', CASHFREE_APP_ID='', CASHFREE_SECRET_KEY='', SUPABASE_SERVICE_ROLE_KEY='')
original_connect = socket.socket.connect
original_connect_ex = socket.socket.connect_ex
def connect(sock, address):
    if isinstance(address, tuple) and str(address[0]) not in ('127.0.0.1', '::1', 'localhost'):
        raise RuntimeError('External network disabled for independent recheck')
    return original_connect(sock, address)
def connect_ex(sock, address):
    if isinstance(address, tuple) and str(address[0]) not in ('127.0.0.1', '::1', 'localhost'):
        raise RuntimeError('External network disabled for independent recheck')
    return original_connect_ex(sock, address)
socket.socket.connect, socket.socket.connect_ex = connect, connect_ex
paths = ['routers/admin.py','routers/cart.py','routers/admin_extended.py','routers/cashfree_router.py','routers/orders.py','routers/fcm.py','routers/websockets.py','utils/firebase.py','utils/cache.py','tests/test_production_blockers_resolved.py','tests/conftest.py']
def hashes(): return {path:hashlib.sha256((BACKEND/path).read_bytes()).hexdigest() for path in paths}
initial = hashes()
import pytest
class Results:
    def __init__(self):
        self.collected = self.passed = self.failed = self.errors = self.skipped = 0
        self.failed_tests = []
    def pytest_collection_finish(self,session): self.collected = len(session.items)
    def pytest_runtest_logreport(self,report):
        if report.when == 'call':
            if report.passed: self.passed += 1
            elif report.failed:
                self.failed += 1
                self.failed_tests.append(report.nodeid)
            elif report.skipped: self.skipped += 1
        elif report.failed:
            self.errors += 1
            self.failed_tests.append(report.nodeid + ':' + report.when)
        elif report.skipped and report.when == 'setup': self.skipped += 1
results = Results()
started = time.monotonic()
exit_code = pytest.main(['tests/', '--ignore=tests/test_migration_full.py', '-q', '--tb=short'],plugins=[results])
record = dict(vars(results),exit_code=int(exit_code),elapsed_seconds=round(time.monotonic()-started,2),initial_hashes=initial,final_hashes=hashes(),scope='SQLite; dotenv disabled; dummy credentials; external network blocked; unmocked migration_full gateway/KOT suite excluded')
output = BACKEND.parent/'docs/verification/2026-10-19-r3-python-results.json'
output.write_text(json.dumps(record,indent=2),encoding='utf-8')
print('RECHECK_SUMMARY',json.dumps({k:record[k] for k in ['collected','passed','failed','errors','skipped','exit_code','elapsed_seconds']}))
sys.exit(exit_code)







