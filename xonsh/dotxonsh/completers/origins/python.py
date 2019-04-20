from xonsh.completers.python import complete_python as complete_origin


def complete_python(prefix, line, start, end, ctx):
    """Complete git."""
    result = complete_origin(prefix, line, start, end, ctx)
    if isinstance(result, tuple):
        result, _ = result
    if len(result) > 0 and line.endswith(' '):
        # not do completes (mostly) useless things
        raise StopIteration
    return result
