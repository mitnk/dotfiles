#!/usr/local/bin/python3
import glob
import os

ROOT = os.getenv('ENOTES_DIR')

if not ROOT or not os.path.exists(ROOT):
    print('invalid enote root: {}'.format(ROOT))
    exit(1)
if not ROOT.endswith('/'):
    ROOT += '/'


def get_md_list(root):
    return glob.glob(os.path.join(root, '*.md'))


def get_category_list(args):
    result = []
    for root, dirs, files in os.walk(ROOT):
        prefix = root.replace(ROOT, '')
        if prefix.startswith('.git') or prefix.startswith('statics'):
            continue

        if args.category and not prefix.startswith(args.category):
            continue

        md_count = len(get_md_list(root))
        if md_count == 0:
            continue

        result.append((prefix, md_count))

    for p, c in sorted(result):
        print('- {} [{}]'.format(p, c))


def main(args):
    if args.cl:
        get_category_list(args)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--cl', '--category-list', action='store_true')
    parser.add_argument('-c', '--category', type=str)
    args = parser.parse_args()
    main(args)
