"""Apply only reviewed HUD/store files to the two authorized Android apps."""
from pathlib import Path
import shutil,json
workspace=Path(__file__).resolve().parents[2]
stage=workspace/'artifacts/hud-refinement-20260930/stage'
projects={'math':Path('C:/Projects/minikMath'),'bounce':Path('C:/Projects/MinikPaddleAndLearn')}
changed={}
for app,project in projects.items():
    project=project.resolve(); changed[app]=[]
    for source in sorted((stage/app).rglob('*')):
        if not source.is_file():continue
        rel=source.relative_to(stage/app);target=(project/rel).resolve()
        assert target.is_relative_to(project)
        assert rel.as_posix().startswith(('app/src/main/assets/www/','play-store/2026-09-29/','docs/')) or rel.as_posix()=='tools/check-pingpong-parity.cjs'
        if target.exists() and target.read_bytes()==source.read_bytes():continue
        backup=project/'artifacts/hud-refinement-20260930/before'/rel
        if target.exists() and not backup.exists():backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,backup)
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target);changed[app].append(rel.as_posix())
print(json.dumps(changed,indent=2))
