# Fixture README

HTML image (remote): <img src="https://example.com/pic.png" alt="pic">

Markdown image (remote): ![remote](https://example.com/pic2.png)

HTML link (remote): <a href="https://example.com/page">page</a>

Markdown link (remote): [page2](https://example.com/page2)

Nested badge: [![badge](https://img.shields.io/badge/-ok-green)](https://example.com/target)

Relative image (exists): ![ok](assets/ok.svg)

Relative image (missing): ![missing](assets/missing.svg)

Non-http scheme: [bad](file:///etc/hosts)

LinkedIn (bot-blocked): [in](https://www.linkedin.com/in/someone)

In-page anchor (skip): [toc](#fixture-readme)

Relative image with query suffix: ![raw](assets/ok.svg?raw=true)

Relative link with fragment: [deep](README.md#fixture-readme)

Relative link to a directory: [dir](assets)
