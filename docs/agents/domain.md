# Domain Docs

How engineering skills consume Grocery POS domain documentation when exploring the codebase.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root.
- **`docs/adr/`**: read ADRs that touch the area you are about to work in.
- **`docs/design-system.md`**: read the Emil Kowalski design engineering principles and interaction standards.

## File structure

Single-context repository layout:

```
/
├── GLOSSARY.md
├── docs/
│   ├── adr/
│   │   ├── 0001-offline-first-drift-sqlite.md
│   │   ├── 0002-peer-http-sync-shelf-dio.md
│   │   └── 0003-delta-inventory-reconciliation.md
│   ├── design-system.md
│   └── agents/
│       ├── issue-tracker.md
│       ├── triage-labels.md
│       └── domain.md
└── .scratch/
    └── grocery-pos/
        ├── spec.md
        └── issues/
```

## Use the glossary's vocabulary

When output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

