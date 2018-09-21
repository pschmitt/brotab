#!/usr/bin/env python3

"""
This is a browser tab client. It allows listing, closing and creating
tabs in browsers from command line. Currently Firefox and Chrome are
supported.

To enable RPC in Chrome, run it as follows:

    chromium-browser --remote-debugging-port=9222 &!

To enable RPC in Firefox, install Mozrepl plugin:

    https://addons.mozilla.org/en-US/firefox/addon/mozrepl/
    https://github.com/bard/mozrepl/wiki

    Change port to 4242, and tick Tools -> MozRepl -> Activate on startup

Todo:
    [_] add rt-browsers support for Chromium (grab tabs from from database)
    [_] add rt-browsers-history to grab rt tickets from browser history

News:

    Starting from Firefox 55 mozrepl is not working anymore. Even worse, they
    guarantee that since Firefox 57 extensions that have not transitioned to
    WebExtensions technology will stop working. I need to find a replacement
    for mozrepl. As I need only a limited set of its potential functionality,
    implementing my own extension sounds like a viable idea. Two things are
    required:

        0. extensions setup basics:

        https://developer.mozilla.org/en-US/Add-ons/WebExtensions/What_are_WebExtensions

        1. tabs api:

        https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/tabs
        https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/tabs/query
        https://github.com/mdn/webextensions-examples/blob/master/tabs-tabs-tabs/tabs.js

        2. native messaging:

        https://developer.mozilla.org/en-US/Add-ons/WebExtensions/Native_messaging
        https://developer.mozilla.org/en-US/Add-ons/WebExtensions/manifest.json/permissions
        https://github.com/mdn/webextensions-examples/tree/master/native-messaging

"""

import os
import re
import sys
import shutil
import logging
from string import ascii_lowercase
from argparse import ArgumentParser
from functools import partial
from itertools import groupby

from brotab.inout import is_port_accepting_connections
from brotab.inout import read_stdin
from brotab.utils import split_tab_ids
from brotab.search.query import query
from brotab.search.index import index
from brotab.api import SingleMediatorAPI, MultipleMediatorsAPI


MIN_MEDIATOR_PORT = 4625
MAX_MEDIATOR_PORT = MIN_MEDIATOR_PORT + 10

FORMAT = '%(asctime)-15s %(levelname)-10s %(message)s'
logging.basicConfig(
    format=FORMAT,
    filename='/tmp/brotab.log',
    level=logging.DEBUG)
logger = logging.getLogger('brotab')
logger.info('Logger has been created')


def create_clients():
    ports = range(MIN_MEDIATOR_PORT, MAX_MEDIATOR_PORT)
    result = [SingleMediatorAPI(prefix, port=port)
              for prefix, port in zip(ascii_lowercase, ports)
              if is_port_accepting_connections(port)]
    logger.info('Created clients: %s', result)
    return result


def move_tabs(args):
    logger.info('Moving tabs')
    api = MultipleMediatorsAPI(create_clients())
    api.move_tabs([])


def list_tabs(args):
    """
    Use this to show duplicates:
        bt list | sort -k3 | uniq -f2 -D | cut -f1 | bt close
    """
    logger.info('Listing tabs')
    api = MultipleMediatorsAPI(create_clients())
    tabs = api.list_tabs([])
    #print('\n'.join([tab.encode('utf8') for tab in tabs]))
    # print(u'\n'.join(tabs).encode('utf8'))
    # print(u'\n'.join(tabs))

    message = '\n'.join(tabs) + '\n'
    sys.stdout.buffer.write(message.encode('utf8'))


def close_tabs(args):
    #urls = [line.strip() for line in sys.stdin.readlines()]

    # Try stdin if arguments are empty
    tab_ids = args.tab_ids
    # print(read_stdin())
    if len(args.tab_ids) == 0:
        tab_ids = split_tab_ids(read_stdin().strip())

    logger.info('Closing tabs: %s', tab_ids)
    #api = MultipleMediatorsAPI([SingleMediatorAPI('f')])
    api = MultipleMediatorsAPI(create_clients())
    tabs = api.close_tabs(tab_ids)


def activate_tab(args):
    logger.info('Activating tab: %s', args.tab_id)
    #api = MultipleMediatorsAPI([SingleMediatorAPI('f')])
    api = MultipleMediatorsAPI(create_clients())
    api.activate_tab(args.tab_id)


def show_active_tab(args):
    logger.info('Showing active tabs: %s', args)
    #api = MultipleMediatorsAPI([SingleMediatorAPI('f')])
    api = MultipleMediatorsAPI(create_clients())
    tabs = api.get_active_tabs(args)
    print('\n'.join(tabs))
    # api.activate_tab(args.tab_id)


def search_tabs(args):
    for result in query(args.sqlite, args.query):
        print('\t'.join([result.tab_id, result.title, result.snippet]))


def index_tabs(args):
    if args.tsv is None:
        args.tsv = '/tmp/tabs.tsv'
        args.cleanup = True
        logger.info(
            'index_tabs: retrieving tabs from browser into file %s', args.tsv)
        import time
        start = time.time()
        get_text(args)
        delta = time.time() - start
        logger.info('getting text took %s', delta)

    start = time.time()
    index(args.sqlite, args.tsv)
    delta = time.time() - start
    logger.info('sqlite create took %s', delta)


def open_urls(args):
    """
    curl -X POST 'http://localhost:4626/open_urls' -F 'urls=@urls.txt'
    curl -X POST 'http://localhost:4627/open_urls' -F 'urls=@urls.txt' -F 'window_id=749'

    where urls.txt containe one url per line (not JSON)
    """
    prefix, window_id = None, None
    try:
        prefix, window_id = args.prefix_window_id.split('.')
        prefix += '.'
    except ValueError:
        prefix = args.prefix_window_id

    urls = [line.strip() for line in sys.stdin.readlines()]
    logger.info('Openning URLs from stdin, prefix "%s", window_id "%s": %s',
                prefix, window_id, urls)
    api = MultipleMediatorsAPI(create_clients())
    api.open_urls(urls, prefix, window_id)


def get_words(args):
    # return tab.execute({javascript: "
    # [...new Set(document.body.innerText.match(/\w+/g))].sort().join('\n');
    # "})
    import time
    start = time.time()
    logger.info('Get words from tabs: %s', args.tab_ids)
    api = MultipleMediatorsAPI(create_clients())
    words = api.get_words(args.tab_ids)
    print('\n'.join(words))
    delta = time.time() - start
    #print('DELTA TOTAL', delta, file=sys.stderr)


def get_text(args):
    logger.info('Get text from tabs')
    api = MultipleMediatorsAPI(create_clients())
    tabs = api.get_text([])

    if args.cleanup:
        pattern = re.compile(r'\s+')
        old_tabs = tabs
        tabs = []
        for line in old_tabs:
            tab_id, title, url, text = line.split('\t')
            text = re.sub(pattern, ' ', text)
            tabs.append('\t'.join([tab_id, title, url, text]))

    message = '\n'.join(tabs) + '\n'
    if args.tsv is None:
        sys.stdout.buffer.write(message.encode('utf8'))
    else:
        with open(args.tsv, 'w') as file_:
            file_.write(message)


def show_duplicates(args):
    # I'm not using uniq here because it's not easy to get duplicates
    # only by a single column. awk is much easier in this regard.
    #print('bt list | sort -k3 | uniq -f2 -D | cut -f1 | bt close')
    print("Show duplicates by Title:")
    print(
        "bt list | sort -k2 | awk -F$'\\t' '{ if (a[$2]++ > 0) print }' | cut -f1 | bt close")
    print("")
    print("Show duplicates by URL:")
    print(
        "bt list | sort -k3 | awk -F$'\\t' '{ if (a[$3]++ > 0) print }' | cut -f1 | bt close")


def _get_window_id(tab):
    ids, _title, _url = tab.split('\t')
    client_id, window_id, tab_id = ids.split('.')
    return '%s.%s' % (client_id, window_id)


def _print_available_windows(tabs):
    for key, group in groupby(sorted(tabs), _get_window_id):
        group = list(group)
        print('%s\t%s' % (key, len(group)))


def show_windows(args):
    logger.info('Showing windows')
    api = MultipleMediatorsAPI(create_clients())
    tabs = api.list_tabs([])
    _print_available_windows(tabs)


def show_clients(args):
    logger.info('Showing clients')
    for client in create_clients():
        print(client)


def install_mediator(args):
    logger.info('Installing mediators')
    bt_mediator_path = shutil.which('bt_mediator')

    native_app_manifests = [
        ('mediator/firefox_mediator.json',
         '~/.mozilla/native-messaging-hosts/brotab_mediator.json'),
        ('mediator/chromium_mediator.json',
         '~/.config/chromium/NativeMessagingHosts/brotab_mediator.json'),
        ('mediator/chromium_mediator.json',
         '~/.config/google-chrome/NativeMessagingHosts/brotab_mediator.json'),
    ]

    if args.tests:
        native_app_manifests.append(
            ('mediator/chromium_mediator_tests.json',
             '~/.config/chromium/NativeMessagingHosts/brotab_mediator.json'),
        )

    from pkg_resources import resource_string
    for filename, destination in native_app_manifests:
        destination = os.path.expanduser(os.path.expandvars(destination))
        template = resource_string(__name__, filename).decode('utf8')
        manifest = template.replace(r'$PWD/brotab_mediator.py',
                                    bt_mediator_path)
        logger.info('Installing template %s into %s', filename, destination)
        print('Installing mediator manifest %s' % destination)

        os.makedirs(os.path.dirname(destination), exist_ok=True)
        with open(destination, 'w') as file_:
            file_.write(manifest)

    print('Link to Firefox extension: https://addons.mozilla.org/en-US/firefox/addon/brotab/')
    print('Link to Chrome (Chromium) extension: https://chrome.google.com/webstore/detail/brotab/mhpeahbikehnfkfnmopaigggliclhmnc/')


def executejs(args):
    pass


def no_command(parser, args):
    print('No command has been specified')
    parser.print_help()
    return 1


def parse_args(args):
    parser = ArgumentParser(
        description='''
        bt (brotab = Browser Tabs) is a command-line tool that helps you manage
        browser tabs. It can help you list, close, reorder, open and activate
        your tabs.
        ''')

    subparsers = parser.add_subparsers()
    parser.set_defaults(func=partial(no_command, parser))

    parser_move_tabs = subparsers.add_parser(
        'move',
        help='''
        move tabs around. This command lists available tabs and runs
        the editor. In the editor you can 1) reorder tabs -- tabs will
        be moved in the browser 2) delete tabs -- tabs will be closed
        3) change window ID of the tabs -- tabs will be moved to
        specified windows
        ''')
    parser_move_tabs.set_defaults(func=move_tabs)

    parser_list_tabs = subparsers.add_parser(
        'list',
        help='''
        list available tabs. The command will request all available clients
        (browser plugins, mediators), and will display browser tabs in the
        following format:
        "<prefix>.<window_id>.<tab_id><Tab>Page title<Tab>URL"
        ''')
    parser_list_tabs.set_defaults(func=list_tabs)

    parser_close_tabs = subparsers.add_parser(
        'close',
        help='''
        close specified tab IDs. Tab IDs should be in the following format:
        "<prefix>.<window_id>.<tab_id>". You can use "list" command to obtain
        tab IDs (first column)
        ''')
    parser_close_tabs.set_defaults(func=close_tabs)
    parser_close_tabs.add_argument('tab_ids', type=str, nargs='*',
                                   help='Tab IDs to close')

    parser_activate_tab = subparsers.add_parser(
        'activate',
        help='''
        activate given tab ID. Tab ID should be in the following format:
        "<prefix>.<window_id>.<tab_id>"
        ''')
    parser_activate_tab.set_defaults(func=activate_tab)
    parser_activate_tab.add_argument('tab_id', type=str, nargs=1,
                                     help='Tab ID to activate')

    parser_active_tab = subparsers.add_parser(
        'active',
        help='''
        display active tab for each client/window in the following format:
        "<prefix>.<window_id>.<tab_id>"
        ''')
    parser_active_tab.set_defaults(func=show_active_tab)

    parser_search_tabs = subparsers.add_parser(
        'search',
        help='''
        Search across your indexed tabs using sqlite fts5 plugin.
        ''')
    parser_search_tabs.set_defaults(func=search_tabs)
    parser_search_tabs.add_argument('--sqlite', type=str, default='/tmp/tabs.sqlite',
                                    help='sqlite DB filename')
    parser_search_tabs.add_argument('query', type=str, help='Search query')

    parser_index_tabs = subparsers.add_parser(
        'index',
        help='''
        Index the text from browser's tabs. Text is put into sqlite fts5 table.
        ''')
    parser_index_tabs.set_defaults(func=index_tabs)
    parser_index_tabs.add_argument('--sqlite', type=str, default='/tmp/tabs.sqlite',
                                   help='sqlite DB filename')
    parser_index_tabs.add_argument('--tsv', type=str, default=None,
                                   help='get text from tabs and index the results')

    parser_open_urls = subparsers.add_parser(
        'open',
        help='''
        open URLs from the stdin (one URL per line). One positional argument is
        required: <prefix>.<window_id> OR <client>. If window_id is not
        specified, URL will be opened in the active window of the specifed
        client
        ''')
    parser_open_urls.set_defaults(func=open_urls)
    parser_open_urls.add_argument(
        'prefix_window_id', type=str,
        help='Client prefix and window id, e.g. b.20')

    parser_get_words = subparsers.add_parser(
        'words',
        help='''
        show sorted unique words from all active tabs of all clients. This is
        a helper for webcomplete deoplete plugin that helps complete words
        from the browser
        ''')
    parser_get_words.set_defaults(func=get_words)
    parser_get_words.add_argument('tab_ids', type=str, nargs='*',
                                  help='Tab IDs to get words from')

    parser_get_text = subparsers.add_parser(
        'text',
        help='''
        show text form all tabs
        ''')
    parser_get_text.set_defaults(func=get_text)
    parser_get_text.add_argument('--tsv', type=str, default=None,
                                 help='tsv file to save results to')
    parser_get_text.add_argument('--cleanup', action='store_true',
                                 default=False,
                                 help='force removal of extra whitespace')

    parser_show_duplicates = subparsers.add_parser(
        'dup',
        help='''
        display reminder on how to show duplicate tabs using command-line tools
        ''')
    parser_show_duplicates.set_defaults(func=show_duplicates)

    parser_show_windows = subparsers.add_parser(
        'windows',
        help='''
        display available prefixes and window IDs, along with the number of
        tabs in every window
        ''')
    parser_show_windows.set_defaults(func=show_windows)

    parser_show_clients = subparsers.add_parser(
        'clients',
        help='''
        display available browser clients (mediators), their prefixes and
        address (host:port), native app PIDs, and browser names
        ''')
    parser_show_clients.set_defaults(func=show_clients)

    parser_install_mediator = subparsers.add_parser(
        'install',
        help='''
        configure browser settings to use bt mediator (native messaging app)
        ''')
    parser_install_mediator.add_argument('--tests', action='store_true',
                                         default=False,
                                         help='install testing version of '
                                         'manifest for chromium')
    parser_install_mediator.set_defaults(func=install_mediator)

    return parser.parse_args(args)


def run_commands(args):
    args = parse_args(args)
    result = 0
    try:
        result = args.func(args)
    except BrokenPipeError:
        pass
    return result


def main():
    exit(run_commands(sys.argv[1:]))


if __name__ == '__main__':
    main()