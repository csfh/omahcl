# Contributing

By sending a pull request or otherwise contributing to Omarchy HCL, you agree to the [CLA](CLA.md). Your contribution becomes the property of Christoffer Hallas.

If you cannot make that assignment, do not contribute. If this is work for an employer, get permission first.

Omarchy HCL is licensed under the [MIT License](LICENSE).

## Before you open a pull request

There is no hosted CI. Run the checks locally and say in the pull request that they pass:

```sh
bin/ci
```

That runs `bin/rails test`, `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit` and `bin/importmap audit`. [AGENTS.md](AGENTS.md) lists the project's rules, including what not to add back (accounts, payments, email) and what must not change (the collector's digest).
