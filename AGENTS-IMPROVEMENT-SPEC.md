# AGENTS Improvement Spec

**Date:** 2026-04-29  
**Scope:** `/workspaces/workspaces` — blank repository with only `.devcontainer/devcontainer.json`

---

## Current State

| Artifact | Status | Notes |
|---|---|---|
| `AGENTS.md` | ❌ Missing | No agent guidance exists |
| `.ona/skills/` | ❌ Missing | No Ona skill definitions |
| `.cursor/rules/` | ❌ Missing | No Cursor rules |
| `.github/` | ❌ Missing | No CI, PR templates, or issue templates |
| `.gitignore` | ❌ Missing | Dependency directories could be committed accidentally |
| `automations.yaml` | ❌ Missing | No Ona automation tasks or services defined |
| `README.md` | ❌ Missing | No project description or onboarding instructions |
| `.devcontainer/devcontainer.json` | ⚠️ Exists, incomplete | Universal 10 GB image; no `postCreateCommand`, no `features`, no `forwardPorts` |
| Source code | ❌ Missing | Repository has zero commits and no project files |

---

## What's Good

- `devcontainer.json` is present and syntactically valid.
- Inline comments in `devcontainer.json` point to lighter language-specific images and explain the trade-off — useful guidance for whoever sets up the project.
- The git repository is initialized and ready for first commit.

---

## What's Missing

### 1. `AGENTS.md`
No file exists to tell AI agents how to work in this repository. Agents have no context about:
- Project purpose, language, or stack
- Build, test, and lint commands
- Commit message conventions
- PR workflow and branch naming
- Files or directories that must not be modified
- Environment secrets or required env vars

### 2. `.gitignore`
No ignore rules. Any `npm install`, `pip install`, or similar command will stage dependency directories unless the developer manually avoids it.

### 3. Ona Automations (`automations.yaml`)
No tasks or services are defined. The environment starts with no automated setup (install deps, run dev server, run tests).

### 4. `.ona/skills/`
No project-specific skills. Reusable workflows (e.g., "run tests", "deploy to staging") are not captured.

### 5. `.github/`
No CI pipeline, PR template, or issue templates. Code review and contribution workflows are undefined.

### 6. `README.md`
No onboarding documentation. A new contributor (human or agent) has no starting point.

---

## What's Wrong

### `devcontainer.json` — oversized image with no bootstrap
- **Problem:** `mcr.microsoft.com/devcontainers/universal:4.0.1-noble` is ~10 GB. Without a defined project stack, this is the only option, but it should be replaced with a targeted image once the stack is chosen.
- **Problem:** No `postCreateCommand` means the environment is not self-bootstrapping. A developer must manually install dependencies after container creation.
- **Problem:** No `features` block. Common tools (Docker-in-Docker, GitHub CLI, specific language runtimes) are not pinned.
- **Problem:** No `forwardPorts`. If a dev server is added later, port forwarding will not be pre-configured.

---

## Improvement Spec

### Priority 1 — Immediate (unblocks all agent work)

#### 1.1 Create `AGENTS.md`

Minimum viable content:

```markdown
# AGENTS.md

## Project
<!-- TODO: describe the project purpose and primary language/stack -->

## Environment
- Dev container: `.devcontainer/devcontainer.json`
- Bootstrap: `<!-- TODO: e.g. npm install / pip install -r requirements.txt -->`

## Commands
| Purpose | Command |
|---|---|
| Install deps | `<!-- TODO -->` |
| Run dev server | `<!-- TODO -->` |
| Run tests | `<!-- TODO -->` |
| Lint | `<!-- TODO -->` |
| Build | `<!-- TODO -->` |

## Conventions
- Branch naming: `<type>/<short-description>` (e.g. `feat/add-login`, `fix/null-check`)
- Commit messages: `<type>: <what changed and why>` (types: feat, fix, chore, docs, refactor, test)
- PRs target `main`; squash merge preferred

## Off-limits
- Do not modify `.devcontainer/` without explicit instruction
- Do not commit secrets or `.env` files

## Secrets / env vars
<!-- TODO: list required env vars and where to obtain them -->
```

**Acceptance criteria:** File exists at repo root; all `TODO` placeholders are filled once the stack is decided.

---

#### 1.2 Create `.gitignore`

Must include patterns for the chosen stack. Until the stack is known, add a safe baseline:

```gitignore
# Dependencies
node_modules/
vendor/
venv/
.venv/
__pycache__/
*.pyc

# Build output
dist/
build/
out/
*.egg-info/

# Environment
.env
.env.*
!.env.example

# IDE / OS
.vscode/
.idea/
.DS_Store
*.swp

# Logs
*.log
npm-debug.log*
yarn-debug.log*
```

**Acceptance criteria:** File exists at repo root before any `npm install` / `pip install` / equivalent is run.

---

### Priority 2 — Short-term (improves agent and developer experience)

#### 2.1 Add `automations.yaml`

Define at minimum:
- An `install` task that runs the dependency install command on environment creation.
- A `dev` service that starts the development server.
- A `test` task that runs the test suite.

Template:

```yaml
tasks:
  install:
    name: Install dependencies
    command: "# TODO: e.g. npm ci"

  test:
    name: Run tests
    command: "# TODO: e.g. npm test"

services:
  dev:
    name: Dev server
    command: "# TODO: e.g. npm run dev"
    ready_on:
      port: 3000  # adjust to actual port
```

**Acceptance criteria:** `gitpod automations task list` shows `install` and `test`; `gitpod automations service list` shows `dev`.

---

#### 2.2 Harden `devcontainer.json`

Once the project stack is known:
- Replace `universal:4.0.1-noble` with the appropriate language-specific image.
- Add `postCreateCommand` to run the install task.
- Add `forwardPorts` for the dev server port.
- Pin any required `features`.

Example for a Node.js project:

```json
{
  "name": "<project-name>",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:24",
  "postCreateCommand": "npm ci",
  "forwardPorts": [3000],
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  }
}
```

**Acceptance criteria:** Container starts in under 2 minutes; dev server is accessible immediately after `postCreateCommand` completes.

---

#### 2.3 Add `.github/` scaffolding

- `PULL_REQUEST_TEMPLATE.md` — checklist: tests pass, docs updated, no secrets committed.
- `ISSUE_TEMPLATE/bug_report.md` — reproduction steps, expected vs actual.
- `ISSUE_TEMPLATE/feature_request.md` — motivation, proposed solution.
- `workflows/ci.yml` — run lint + tests on every PR.

**Acceptance criteria:** Opening a PR on GitHub pre-fills the template; CI runs automatically.

---

### Priority 3 — Nice-to-have

#### 3.1 Add `.ona/skills/`

Capture reusable agent workflows as skills once the project has established patterns:
- `run-tests` — how to run, interpret, and fix failing tests in this repo.
- `create-pr` — branch naming, commit format, PR description conventions.
- `deploy` — deployment steps and required approvals.

#### 3.2 Add `README.md`

Minimum sections:
- What the project does (one paragraph)
- Prerequisites
- Getting started (clone → install → run)
- Running tests
- Contributing link

---

## Execution Order

```
1. Create .gitignore                    (unblocks safe dependency install)
2. Create AGENTS.md skeleton            (unblocks agent work immediately)
3. Decide project stack                 (unblocks all stack-specific steps)
4. Fill AGENTS.md TODOs                 (after stack decision)
5. Harden devcontainer.json             (after stack decision)
6. Add automations.yaml                 (after commands are known)
7. Add .github/ scaffolding             (after first PR workflow is needed)
8. Add README.md                        (before first public commit)
9. Add .ona/skills/                     (after patterns are established)
```

---

## Definition of Done

- [ ] `AGENTS.md` exists with no `TODO` placeholders
- [ ] `.gitignore` covers the project's language and toolchain
- [ ] `devcontainer.json` uses a targeted image with `postCreateCommand`
- [ ] `automations.yaml` defines install, test, and dev-server automation
- [ ] `.github/` contains PR template and CI workflow
- [ ] `README.md` covers prerequisites and getting-started steps
- [ ] All files are committed; `git log` shows a meaningful first commit
