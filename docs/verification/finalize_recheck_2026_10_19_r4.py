"""Summarize the R4 review evidence without modifying application files."""
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FLUTTER = ROOT / 'fastkirana_flutter'

def read_json(name):
    return json.loads((HERE / name).read_text(encoding='utf-8-sig'))

def flutter_result(name, exit_code):
    log = (HERE / name).read_text(encoding='utf-8-sig', errors='replace')
    matches = list(re.finditer(r'\d+:\d+ \+(\d+)(?: -(\d+))?: (All tests passed!|Some tests failed\.)', log))
    last = matches[-1] if matches else None
    return dict(log=name, exit_code=exit_code, completed=last is not None,
                passed=int(last[1]) if last else None,
                failed=int(last[2] or 0) if last else None)

initial = read_json('2026-10-19-r4-flutter-final-manifest.json')
normalized_initial = {key.replace('\\', '/'): value for key, value in initial.items()}
final = {p.relative_to(FLUTTER).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest().upper()
         for base in [FLUTTER/'lib', FLUTTER/'test'] for p in base.rglob('*.dart')}
changed = sorted(key for key in normalized_initial.keys() | final.keys()
                 if normalized_initial.get(key) != final.get(key))
core_initial = read_json('2026-10-19-r4-final-run-snapshot.json')
core_final = {key: hashlib.sha256((ROOT/key).read_bytes()).hexdigest().upper() for key in core_initial}
exits = read_json('2026-10-19-r4-rerun-exits.json')
record = dict(
    review='2026-10-19 revision 4',
    reviewed_head='66b1f4a93bb4619eee472943674ecd9c964e8343',
    includes_uncommitted_fixes=True,
    python=read_json('2026-10-19-r4-python-results.json'),
    cart_checks=read_json('2026-10-19-r4-cart-checks.json'),
    flutter_full=flutter_result('2026-10-19-r4-flutter-final.log', 0),
    focused_initial=flutter_result('2026-10-19-r4-flutter-focused.log', 1),
    focused_final=flutter_result('2026-10-19-r4-flutter-focused-final.log', exits['focused_exit_code']),
    offline_reruns=[flutter_result(f"2026-10-19-r4-offline-rerun-{r['attempt']}.log", r['exit_code'])
                    for r in exits['offline_reruns']],
    dart_analysis=dict(exit_code=0, files=7, errors=0, warnings=0, informational=10,
                       log='2026-10-19-r4-dart-analysis-final.log'),
    source_stability=dict(flutter_files=len(final), changed_in_final_runs=changed,
                          flutter_initial=normalized_initial, flutter_final=final,
                          core_initial=core_initial, core_final=core_final,
                          core_changed=[k for k in core_initial if core_initial[k] != core_final[k]]),
    earlier_full_run=read_json('2026-10-19-r4-flutter-source-change-interruption.json'),
    production_source_edited_by_review=False,
    scope_limits=['SQLite execution does not validate PostgreSQL row-lock behavior',
                  'Unmocked migration_full gateway/KOT suite excluded',
                  'No live payment, database, notification or printing verification',
                  'Next.js/TypeScript and graph rebuild not rerun',
                  'Test-binding-specific production branches are not fully exercised by Flutter tests'],
)
output = HERE/'2026-10-19-r4-verification-summary.json'
output.write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps({k:record[k] for k in ['flutter_full','focused_initial','focused_final','offline_reruns','dart_analysis']}, indent=2))
print('Flutter manifest changes:', changed)
print('Core manifest changes:', record['source_stability']['core_changed'])
