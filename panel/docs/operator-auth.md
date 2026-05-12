# Operator Auth

Leikwan Panel separates Agent auth from Operator auth.

## Agent Token

`LEIKWAN_CONTROLLER_TOKEN` is the Agent token. It is used only for Agent register, report, task polling and task result APIs. Agent token cannot call Operator APIs.

## Operator Token

`LEIKWAN_OPERATOR_TOKEN` is the Web / Operator token. It is required for mutating APIs including Plans, Tasks, Network profiles, Entries, Forwards, Apply actions, metadata actions and evidence upload. Operator token cannot call Agent APIs.

## Strict Auth

With `--strict-auth`, every non-health Web API also requires Operator token. Agent APIs still require the Agent token and do not accept Operator token.

## 3.0.0-alpha.1 Demo Apply APIs

These APIs are Operator-protected:

- `POST /api/v1/network-profiles`
- `POST /api/v1/entries`
- `POST /api/v1/entries/:id/apply`
- `POST /api/v1/forwards`
- `POST /api/v1/forwards/:id/apply`

The Controller stores only token fingerprints in audit fields and events. It never stores complete Operator or Agent tokens in timeline or result data.
