# Security

Leikwan Panel `3.0.0-alpha.2` is an alpha apply release with strict boundaries:

- Operator token is required for mutating Web APIs.
- Agent token is only for Agent register/report/task APIs.
- Agent and Operator tokens are not interchangeable.
- Controller never accepts arbitrary command strings.
- Agent never executes `shell -c`, `bash -c` or `eval`.
- Agent write actions are fixed Go handlers or fixed argv only.
- Sensitive values are redacted from API responses, task results, events and logs.
- Backend / landing machines do not need Agent.

