# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

After completing any piece of work — a bug fix, a new feature, a config change, a schema update — commit and push immediately. Do not batch unrelated changes into a single commit.

```bash
git add <specific files>   # never use git add -A or git add .
git commit -m "short imperative summary

Optional body explaining why, not what. Wrap at 72 chars."
git push
```

**Commit message rules:**
- Subject line: imperative mood, ≤ 72 characters (e.g. `Add department filter to employee list`)
- Focus on *why* the change was made, not just *what* changed
- One logical change per commit — schema changes, PHP changes, and Terraform changes should be separate commits unless they are inseparable
- Always push after committing so GitHub reflects the current state
