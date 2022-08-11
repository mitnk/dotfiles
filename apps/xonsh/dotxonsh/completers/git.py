import glob
import os.path
import re
import subprocess
from dotxonsh.completers import git_helper
from dotxonsh.completers.tools import get_complete_set

_USE_PRECOMPILED = True
_CACHE_GIT_ = {}


def _get_cmd_output_with_re(cmd, regex):
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        output = subprocess.check_output(
            ['grep', '-Eo', regex],
            stdin=proc.stdout,
            stderr=subprocess.DEVNULL,
        )
        proc.wait()
    except subprocess.CalledProcessError:
        output = b''
    return output.decode()


def _get_git_alias_info():
    # NOTE: We do not want to precompile alias
    if 'alias_info' in _CACHE_GIT_:
        return _CACHE_GIT_['alias_info']

    info = {}
    output = subprocess.check_output(
        ('git', 'config', '--get-regexp', 'alias'),
    )
    for line in output.decode().split('\n'):
        if not line.strip():
            continue
        l, r = line.split(' ', 1)
        info[l.replace('alias.', '')] = r

    _CACHE_GIT_['alias_info'] = info
    return info


def _get_alias_list():
    return list(_get_git_alias_info().keys())


def _get_command_list():
    if _USE_PRECOMPILED:
        return git_helper.GIT_COMMAND_LIST

    if 'command_list' in _CACHE_GIT_:
        return _CACHE_GIT_['command_list']

    cmd = ['git', 'help', '-a']
    output = _get_cmd_output_with_re(cmd, "'[^']+git-core'")
    output = output.replace("'", '').strip()
    p = os.path.join(output, 'git-*')
    cmd_list = glob.glob(p)
    cmd_list = [re.sub(r'.*/git-', '', x) for x in cmd_list]
    _CACHE_GIT_['command_list'] = cmd_list
    return cmd_list


def _get_git_dashes():
    if _USE_PRECOMPILED:
        return git_helper.GIT_DASHES

    if 'git_dashes' in _CACHE_GIT_:
        return _CACHE_GIT_['git_dashes']

    cmd = ['git', 'help']
    output = _get_cmd_output_with_re(cmd, '\[\-\-?[^][<|]+')
    output = output.replace(' ', '')
    dashes = [re.sub(r'=.*', '=', x[1:]) for x in output.split() if x.strip()]
    _CACHE_GIT_['git_dashes'] = dashes
    return dashes


def _get_command_dashes():
    if _USE_PRECOMPILED:
        return git_helper.GIT_COMMAND_DASHES

    if 'command_dashes' in _CACHE_GIT_:
        return _CACHE_GIT_['command_dashes']

    result = {}
    for cmd in _get_command_list():
        _cmd = ['git', 'help', cmd]
        output = _get_cmd_output_with_re(
            _cmd, '^ {1,}\-\-?[a-zA-Z-]+[a-zA-Z]*=?')
        output = output.replace(' ', '')
        tokens = [x for x in output.split('\n') if x.strip()]
        result[cmd] = set([x for x in tokens if x.strip('-')])

    alias_info = _get_git_alias_info()
    for alias in _get_alias_list():
        cmd = alias_info[alias]
        if ' ' in cmd or cmd[0] == '!':
            continue
        result[alias] = result.get(cmd, None)
    _CACHE_GIT_['command_dashes'] = result
    return result


def _get_completes_subcommand(prefix):
    result = _get_command_list() + _get_alias_list()
    prefix = prefix.strip()
    if not prefix:
        return get_complete_set(result)
    else:
        return get_complete_set([x for x in result if x.startswith(prefix)])


def _get_completes_git_dashes(prefix):
    prefix = prefix.strip()
    git_dashes = _get_git_dashes()
    if not prefix:
        return get_complete_set(git_dashes)
    else:
        return get_complete_set(
            [x for x in git_dashes if x.startswith(prefix)]
        )


def _get_completes_subcommand_dashes(cmd, prefix):
    command_dashes = _get_command_dashes()
    if cmd not in command_dashes or not command_dashes[cmd]:
        return {''}
    result = command_dashes[cmd]
    if not prefix:
        return get_complete_set(result)
    else:
        return get_complete_set([x for x in result if x.startswith(prefix)])


def _get_remote_list():
    cmd = ['git', 'remote']
    output = _get_cmd_output_with_re(cmd, '.*')
    return [x for x in output.split() if x]


def _get_branches():
    cmd = ['git', 'branch', '-a']
    output = _get_cmd_output_with_re(cmd, '\/?[a-zA-Z0-9_-]+$')
    return [x.strip('/') for x in output.split() if x]


def _get_subcommand_subcommands():
    if _USE_PRECOMPILED:
        return git_helper.GIT_SUBCOMMAND_SUBCOMMANDS

    if 'subcommand_subcommands' in _CACHE_GIT_:
        return _CACHE_GIT_['subcommand_subcommands']

    info = {}
    cmd = ['git', 'remote', '-h']
    output = _get_cmd_output_with_re(cmd, 'git remote [a-z-]+')
    output = re.sub('git remote ', '', output)
    tokens = list(set([x.strip() for x in output.split('\n') if x.strip()]))
    info['remote'] = tokens
    _CACHE_GIT_['subcommand_subcommands'] = info
    return info


def _get_completes_subcommand_subcommand(cmd, prefix):
    if cmd in ['pull', 'push', 'fetch', 'getpr']:
        result = _get_remote_list()
    elif cmd in ['checkout', 'co', 'branch', 'br', 'merge']:
        result = _get_branches()
    elif cmd not in _get_subcommand_subcommands():
        return
    else:
        result = _get_subcommand_subcommands()[cmd]

    if not prefix:
        return get_complete_set(result)
    else:
        return get_complete_set([x for x in result if x.startswith(prefix)])


def _get_completes_branches(remote, prefix):
    result = _get_branches()
    if not prefix:
        return get_complete_set(result)
    else:
        return get_complete_set([x for x in result if x.startswith(prefix)])


def complete(prefix, line, start, end, ctx):
    """Complete git."""
    result = re.search(r'^ *git +([a-z]*)$', line)
    if result:
        prefix = result.group(1)
        return _get_completes_subcommand(prefix)

    result = re.search(r'^ *git +(--?[a-z]*)$', line)
    if result:
        prefix = result.group(1)
        return _get_completes_git_dashes(prefix)

    result = re.search(r'^ *git +([a-z]+) +(--?[^ ]*)$', line)
    if result:
        cmd = result.group(1)
        prefix = result.group(2)
        return _get_completes_subcommand_dashes(cmd, prefix)

    result = re.search(r'^ *git +([a-z]+)( +\-.+)? +([a-zA-Z0-9_-]*)$', line)
    if result:
        groups = result.groups()
        cmd = groups[0]
        if groups[-1].strip().startswith('-'):
            prefix = ''
        else:
            prefix = groups[-1]
        return _get_completes_subcommand_subcommand(cmd, prefix)

    result = re.search(
        r'^ *git +(pull|push|fetch) +(\w+-*\w*) +([a-zA-Z0-9_-]*)$', line)
    if result:
        remote = result.group(2)
        prefix = result.group(3)
        return _get_completes_branches(remote, prefix)
