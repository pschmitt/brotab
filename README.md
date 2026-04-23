# BruvTab

![GitHub](https://img.shields.io/github/license/balta2ar/bruvtab)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/balta2ar/bruvtab)
[![PyPI version](https://badge.fury.io/py/bruvtab.svg)](https://badge.fury.io/py/bruvtab)
![Mozilla Add-on](https://img.shields.io/amo/v/bruvtab)

Control your browser's tabs from the terminal.

## About

```txt
No command has been specified
usage: bruvtab [-h] {move,list,close,activate,search,open,words,text,html,dup,windows,clients} ...

bruvtab (bruvtab = Browser Tabs) is a command-line tool that helps you manage browser tabs. It can
help you list, close, reorder, open and activate your tabs.

positional arguments:
  {move,list,close,activate,active,search,index,open,words,text,html,dup,windows,clients,install}
    move                move tabs around. This command lists available tabs and runs
                        the editor. In the editor you can 1) reorder tabs -- tabs
                        will be moved in the browser 2) delete tabs -- tabs will be
                        closed 3) change window ID of the tabs -- tabs will be moved
                        to specified windows
    list                list available tabs. The command will request all available
                        clients (browser plugins, mediators), and will display
                        browser tabs in the following format:
                        "<prefix>.<window_id>.<tab_id><Tab>Page title<Tab>URL"
    close               close specified tab IDs. Tab IDs should be in the following
                        format: "<prefix>.<window_id>.<tab_id>". You can use "list"
                        command to obtain tab IDs (first column)
    activate            activate given tab ID. Tab ID should be in the following
                        format: "<prefix>.<window_id>.<tab_id>"
    active              display active tabs for each client/window in the following
                        format: "<prefix>.<window_id>.<tab_id>"
    search              Search across your indexed tabs using sqlite fts5 plugin.
    query               Filter tabs using chrome.tabs api.
    index               Index the text from browser's tabs. Text is put into sqlite
                        fts5 table.
    open                open URLs from the stdin (one URL per line). One positional
                        argument is required: <prefix>.<window_id> OR <client>. If
                        window_id is not specified, URL will be opened in the active
                        window of the specifed client
    navigate            navigate to URLs. There are two ways to specify tab ids and
                        URLs: 1. stdin: lines with pairs of "tab_id<tab>url" 2.
                        arguments: bruvtab navigate <tab_id> "<url>", e.g. bruvtab navigate b.20.1
                        "https://google.com" stdin has the priority.
    update              Update tabs state, e.g. URL. There are two ways to specify
                        updates: 1. stdin, pass JSON of the form: [{"tab_id":
                        "b.20.130", "properties": {"url": "http://www.google.com"}}]
                        Where "properties" can be anything defined here:
                        https://developer.mozilla.org/en-US/docs/Mozilla/Add-
                        ons/WebExtensions/API/tabs/update Example: echo
                        '[{"tab_id":"a.2118.2156",
                        "properties":{"url":"https://google.com"}}]' | bruvtab update 2.
                        arguments, e.g.: bruvtab update -tabId b.1.862
                        -url="http://www.google.com" +muted
    words               show sorted unique words from all active tabs of all
                        clients. This is a helper for webcomplete deoplete plugin
                        that helps complete words from the browser
    text                show text from all tabs
    html                show html from all tabs
    dup                 display reminder on how to close duplicate tabs using
                        command-line tools
    windows             display available prefixes and window IDs, along with the
                        number of tabs in every window
    clients             display available browser clients (mediators), their
                        prefixes and address (host:port), native app PIDs, and
                        browser names
    install             configure browser settings to use bruvtab mediator (native
                        messaging app)

optional arguments:
  -h, --help            show this help message and exit
  --target TARGET_HOSTS
                        Target hosts IP:Port
```

## Demo [TBD]

Features to show:

* list tabs
* close multiple tabs (fzf)
* move tabs, move, same window
* move tabs, move, different window
* move tabs, move, different browser (NOT IMPLEMENTED)
* move tabs, close
* words, complete in neovim (integration with coc, ncm2, deoplete)
* open tabs by url
* open tab by google query, search (should be extendable, NOT IMPLEMENTED)
* integration with fzf:
  * activate tab
  * close tabs
* integration with rofi:
  * activate tab
  * close tabs
* integration with albert
  * index text of available tabs (requires sqlite 3.25, fts5 plugin)
  * search a tab by text in albert
* show duplicate tabs and close them

## Installation

1. Install command-line client:
```
$ pipx install bruvtab        # preferred method, if pipx not installed: $ sudo apt install pipx
$ uv tool install bruvtab     # alternative
$ pip install --user bruvtab  # alternative
$ sudo pip install bruvtab    # alternative
```
2. Install native app manifests: `bruvtab install`
3. Install Firefox extension: https://addons.mozilla.org/en-US/firefox/addon/bruvtab/
4. Install Chrome (Chromium) / Brave extension: Chrome Web Store publishing is pending for the new BruvTab extension ID.
5. Enjoy! (try `bruvtab clients`, `bruvtab windows`, `bruvtab list`, `bruvtab words`)

## Build, test and manual installation

see [DEVELOPMENT.md](DEVELOPMENT.md)

## Related projects

* [TabFS](https://github.com/osnr/TabFS) -- mounts tabs info a filesystem using FUSE
* [dudetab](https://github.com/CRImier/dudetab) -- collection of useful scripts on top of bruvtab
* [ulauncher-bruvtab](https://github.com/brpaz/ulauncher-bruvtab) -- Ulauncher extension for bruvtab
* [cmp-bruvtab](https://github.com/pschmitt/cmp-bruvtab) -- bruvtab completion for nvim-cmp
* [tab-search](https://github.com/reblws/tab-search) -- shows a nice icon with a number of tabs (Firefox)
* [tab_wrangler](https://github.com/doctorcolossus/tab_wrangler) -- a text-based tab browser for tabaholics
* [vimium-c](https://github.com/gdh1995/vimium-c) -- switch between tabs/history, close tabs with shift-del

## Author

Yuri Bochkarev

## License

MIT
