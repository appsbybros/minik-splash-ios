"""Apply only the reviewed staged files to the explicitly requested Android project."""
from pathlib import Path
import shutil, json

workspace = Path(__file__).resolve().parents[2]
stage = workspace / 'artifacts/bounce-refresh-20260930/android'
target = Path('C:/Projects/MinikPaddleAndLearn').resolve()
assert target.name == 'MinikPaddleAndLearn' and (target / 'gradlew.bat').is_file()
changed = []
for source in sorted(stage.rglob('*')):
    if not source.is_file(): continue
    relative = source.relative_to(stage)
    destination = (target / relative).resolve()
    assert destination.is_relative_to(target)
    if destination.exists() and destination.read_bytes() == source.read_bytes(): continue
    backup = target / 'artifacts/bounce-refresh-20260930/before' / relative
    if destination.exists() and not backup.exists():
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(destination, backup)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    changed.append(relative.as_posix())
report = target / 'artifacts/bounce-refresh-20260930/changed-files.json'
report.parent.mkdir(parents=True, exist_ok=True)
previous = json.loads(report.read_text(encoding='utf-8')) if report.exists() else []
report.write_text(json.dumps(sorted(set(previous + changed)), indent=2), encoding='utf-8')
print(json.dumps({'files_applied':len(changed),'report':str(report)}))
