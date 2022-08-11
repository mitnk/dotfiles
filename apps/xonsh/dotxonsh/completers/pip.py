import re
from dotxonsh.completers.tools import get_complete_set


def _get_completes_subcommand(prefix):
    result = [
        'install',
        'download',
        'uninstall',
        'freeze',
        'list',
        'show',
        'search',
        'wheel',
        'hash',
        'completion',
        'help',
    ]
    prefix = prefix.strip()
    if not prefix:
        return get_complete_set(result)
    else:
        return get_complete_set([x for x in result if x.startswith(prefix)])


def complete(prefix, line, start, end, ctx):
    """Complete git."""
    result = re.search(r'^ *pip[^ ]* +([a-z]*)$', line)
    if result:
        prefix = result.group(1)
        return _get_completes_subcommand(prefix)
