# Domain Docs

How engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repo root, if it exists.
- `docs/adr/`, if it exists.

If these files do not exist, proceed silently. The domain-modeling flow can create or update them when terms or decisions are actually resolved.

## Layout

This is a single-context repo.

Expected structure:

```text
/
|-- CONTEXT.md
|-- docs/
|   `-- adr/
`-- src/
```

## Vocabulary

When output names a domain concept, use the term as defined in `CONTEXT.md`.

If the concept is missing from the glossary, either reconsider the wording or note the gap for domain modeling.

## ADR conflicts

If output contradicts an existing ADR, surface the conflict explicitly instead of silently overriding it.
