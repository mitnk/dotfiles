# Requires Python 3.5+
import importlib.util
import os.path
import sys
import traceback

_XCX_MODULES = []
_PY_35_PLUS = sys.version_info.major == 3 and sys.version_info.minor >= 5


def _xcx_load_complete_modules():
    if not _PY_35_PLUS:
        return
    dir_ = os.path.expanduser('~/.xonsh/dotxonsh/completers')
    if not os.path.isdir(dir_):
        return
    for f in os.listdir(dir_):
        if not f.endswith('.py'):
            continue
        full_path = os.path.join(dir_, f)
        if not os.path.isfile(full_path):
            continue
        try:
            name = f.split('.')[0]
            spec = importlib.util.spec_from_file_location(
                "dotxonsh.completers.{}".format(name), full_path)
            m = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(m)
            if callable(getattr(m, 'complete', None)):
                _XCX_MODULES.append(m)
        except:
            traceback.print_exc()


def complete_xonsh(prefix, line, begidx, endidx, ctx):
    """~/.xonsh completers"""
    try:
        cmd = line.strip().split()[0]
    except IndexError:
        # do not complete on empty input
        raise StopIteration
    for m in _XCX_MODULES:
        try:
            result = m.complete(prefix, line, begidx, endidx, ctx)
        except StopIteration:
            raise
        except Exception:
            traceback.print_exc()
            return
        if result is not None:
            return result


_xcx_load_complete_modules()
