# Security Policy

## Supported versions

ReNotched. is a small hobby project. Only the latest version on the `main` branch receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report them privately through GitHub instead: open the **Security** tab of this repository and choose **Report a vulnerability** ([private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)).

Please include a description of the problem and its impact, steps to reproduce it, and your macOS version and Mac model.

This is a spare-time project, so I cannot promise a response time, but I will read every report and do my best to fix confirmed issues.

## Scope

ReNotched. runs locally on your Mac. It has no server, no user accounts and sends no data to the developer (see the *Privacy* section in the [README](README.md)).

Relevant for security reports:

- ways to run unintended commands through the app,
- unintended access to files or data,
- problems in how the app starts its helper process.

Not in scope:

- vulnerabilities in macOS or the private MediaRemote interface itself (please report those to Apple),
- vulnerabilities in the third-party [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (please report those upstream).

## How the app is built

- The helper process is started with a fixed argument list and **without a shell**, and only from inside the app bundle, so input cannot be turned into commands.
- The helper's output is parsed as JSON with a size limit on the read buffer.
- The app makes no network connections and has no third-party Swift dependencies. The only bundled third-party component is the mediaremote-adapter.
