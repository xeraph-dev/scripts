#!/usr/bin/env python

# requirements.txt
# requests==2.31.0
# beautifulsoup4==4.12.2
# cssutils==2.9.0
# html5lib==1.1

import requests
from argparse import ArgumentParser
import os
import http.server
import sys
import shutil
from bs4 import BeautifulSoup
import cssutils
from urllib.parse import urlparse
from pathlib import Path
import logging
from os.path import normpath

cssutils.log.setLevel(logging.CRITICAL)

site_url = "https://www.composingprograms.com"
site_path = Path(os.curdir).joinpath("site").absolute()

links_cache = set()

if not site_path.exists():
    os.makedirs(site_path, exist_ok=True)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=site_path, **kwargs)


def write(path: Path, content: bytes):
    os.makedirs(path.parent, exist_ok=True)

    with open(path, "wb") as f:
        f.write(content)


def create_href(href: str, url: str):
    if href == ".":
        return url
    href_url = Path(href) if href.startswith("/") else Path(url).parent.joinpath(href)
    href_url = (
        f"{href_url}/"
        if href_url.suffix == "" and not href.endswith("/")
        else f"{href_url}"
    )
    href_url = normpath(href_url)
    return href_url.split("#")[0]


def parseHTML(r: requests.Response):
    r.encoding = "utf-8"
    url = urlparse(r.url)
    file_path = site_path if url.path == "/" else site_path.joinpath(url.path[1:])
    file_path = (
        file_path
        if str(file_path).endswith(".html")
        else file_path.joinpath("index.html")
    )
    write(file_path, r.content)

    soup = BeautifulSoup(r.content, "html5lib")

    for style in soup.select("link[rel='stylesheet']"):
        href = style.get("href")
        if href.startswith("http"):
            print(f"External link {href}")
            continue

        parse(create_href(href, url.path))

    for link in soup.select("a[href]"):
        href = link.get("href")
        if href.startswith("#"):
            continue
        if href.startswith("http"):
            print(f"External link {href}")
            continue

        parse(create_href(href, url.path))


def parseCSS(r: requests.Response):
    r.encoding = "utf-8"
    url = urlparse(r.url)
    file_path = site_path.joinpath(url.path[1:])
    write(file_path, r.content)
    css = cssutils.parseString(r.text)
    for rule in css.cssRules.rulesOfType(cssutils.css.CSSRule.IMPORT_RULE):
        href = (
            Path(rule.href)
            if rule.href.startswith("/")
            else Path(url.path).parent.joinpath(rule.href)
        )
        parse(href)


def parsePython(r: requests.Response):
    r.encoding = "utf-8"
    url = urlparse(r.url)
    file_path = site_path.joinpath(url.path[1:])
    write(file_path, r.content)


def parseZip(r: requests.Response):
    url = urlparse(r.url)
    file_path = site_path.joinpath(url.path[1:])
    write(file_path, r.content)


def parse(path: str):
    if path in links_cache:
        return
    links_cache.add(path)
    print(f"fetching {site_url}{path}")
    r = requests.get(f"{site_url}{path}")
    if not r.ok:
        if not path.endswith("/") and r.status_code == 404:
            return parse(f"{path}/")
        print(f"failed {r.url} with status {r.status_code}")
        return
    contentType = r.headers.get("Content-Type")
    match contentType:
        case "text/html":
            parseHTML(r)
        case "text/css":
            parseCSS(r)
        case "text/x-python":
            parsePython(r)
        case "application/zip":
            parseZip(r)
        case _:
            print(f"unhandled content-type {contentType} for {r.url}")


def download():
    if site_path.exists():
        shutil.rmtree(site_path)

    parse("")


def serve(port: int):
    if port is None:
        port = 8080
    print(f"Serving at http://localhost:{port}")
    http.server.HTTPServer(("", port), Handler).serve_forever()


if __name__ == "__main__":
    parser = ArgumentParser(
        prog="composing-programs-offline",
        description="Download and server the composing programs book",
    )
    subparsers = parser.add_subparsers(required=True, dest="subcommand")
    parser_download = subparsers.add_parser("download")
    parser_serve = subparsers.add_parser("serve")
    parser_serve.add_argument("-p", "--port", type=int)
    args = parser.parse_args(sys.argv[1:])
    kwargs = vars(args)
    globals()[kwargs.pop("subcommand")](**kwargs)
