# AGENTS.md

Instructions for AI coding agents, and a short version for anyone working here. [CONTRIBUTING.md](CONTRIBUTING.md) is the full process.

## What this repository is

hello-galaxy-first-bite shows how to use [first-bite](https://github.com/USAREUR-AF/first-bite) in five steps: decode a capture, tap a link between two systems, turn an interface document into a dictionary, publish decoded records to a goat fabric, and make Cursor-on-Target. The equipment is simulated and the fabric is a stand-in router.

It is one of the Hello Galaxy demonstrations: small, runnable examples, each showing one part of [goat](https://github.com/USAREUR-AF/goatcore). It holds no goat and no first-bite source code.

## Layout

| Path | What |
|---|---|
| `steps/` | one directory per step: `README.md` and `run.sh` |
| `bin/hello-bite` | the runner: `build`, one step, `all`, `list`, `clean` |
| `lib/hello-bite.sh` | shared shell functions |
| `image/Dockerfile`, `FIRST_BITE_REF` | the image every step runs, and the first-bite commit it is built from |
| `icd/`, `dictionaries/harbour-buoy` | the invented interface document, the tables typed from it and the dictionary step 3 builds |
| `device/`, `tools/` | the simulated buoy and shore station; subscribers and checks |
| `fabric/` | the stand-in goatnet of step 4 |

## Before you push

CI (`.github/workflows/ci.yml`) runs these; none needs a goatnet:

```bash
shellcheck -e SC1090,SC1091,SC2034 lib/hello-bite.sh steps/*/run.sh bin/hello-bite
shellcheck fabric/make-certs.sh
bin/hello-bite build --goat
NO_COLOR=1 bin/hello-bite all
```

Every directory under `steps/` holds a `README.md` and an executable `run.sh`, and every file in `tools/` and `device/` is executable; CI checks both. A change to `icd/` or `icd/tables/` is followed by `bin/hello-bite 3-dictionary --record`, and the "What you should see" block of a step's README is pasted from a run, never written by hand.

## Rules

1. **Nothing from a real deployment.** No hostname, domain, address, key or person of a real goatnet goes into a file or a commit message. Use made-up names, documentation addresses (RFC 5737) and `example.org` mail. The interface document is invented; no fielded message format goes into `icd/` or `dictionaries/`.
2. **Commits.** Conventional Commits subject of 100 characters or fewer, with a scope (`fix(<component>): …`). Every commit is signed off (`git commit -s`, the DCO) and signed with a key GitHub verifies. The organization's required check `verified-commits` refuses a pull request that holds an unverified commit.
3. **One logical change per pull request.**
4. **Vulnerabilities** go through [SECURITY.md](SECURITY.md), never a public issue.

The contribution guide for goat as a whole is [goatcore CONTRIBUTING.md](https://github.com/USAREUR-AF/goatcore/blob/main/CONTRIBUTING.md).
