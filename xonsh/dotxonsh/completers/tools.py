def get_complete_set(L):
    if len(L) == 1 and not L[0].endswith('='):
        return set([L[0] + ' '])
    return set(L)
