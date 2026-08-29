# Out-of-process plugin providers

OMacOS never loads third-party code into the privileged native shell. A plugin is a directory containing `manifest.json` plus an executable provider named by `provider.command`.

Install one with `omacos plugin install /path/to/plugin`, enable it with `omacos plugin enable ID`, and invoke it with `omacos plugin run ID ACTION [ARG...]`. The command must be a relative filename inside its plugin directory; absolute paths and parent traversal are rejected.

The provider receives the requested action as its first argument and prints exactly one JSON object. A `status` response should use this shape:

```json
{
  "schemaVersion": 1,
  "title": "Example service",
  "summary": "Connected",
  "items": [
    { "id": "node-1", "label": "Studio", "detail": "Online" }
  ]
}
```

Providers run with the current user’s permissions in a separate process. Installation does not grant Accessibility, Screen Recording, Microphone, keychain, or other privacy access. A future signed provider protocol can add richer native rendering without changing this isolation boundary.
