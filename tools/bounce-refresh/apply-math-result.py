"""Mirror the existing Bounce result-badge width fix into Math, and nothing else."""
from pathlib import Path
import shutil
root = Path('C:/Projects/minikMath').resolve()
file = (root/'app/src/main/assets/www/pingpong/pong-layout.css').resolve()
assert file.is_relative_to(root) and file.is_file()
text = file.read_text(encoding='utf-8')
marker = '/* Finished-match toolbar: give the win/lose caption room instead of clipping it above the screen. */'
fix = marker + '\nhtml.minik-android-inset-host[dir] body.pong-compact-landscape[data-view="pong"]:not(.pong-waiting):not(.pong-immersive-playing) .pong-landscape-center > .pong-status-slot{min-width:136px;}\n'
reference = Path('C:/Projects/MinikPaddleAndLearn/app/src/main/assets/www/pong-layout.css').read_text(encoding='utf-8')
assert fix.strip() in reference
backup = root/'artifacts/result-banner-20260930/pong-layout-before.css'
if marker not in text:
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists(): shutil.copy2(file, backup)
    file.write_text(text.rstrip()+'\n\n'+fix,encoding='utf-8',newline='\n')
    print('Applied existing Bounce result-badge width rule to '+str(file))
else: print('Result-badge width rule already present.')
