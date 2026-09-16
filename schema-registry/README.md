# IBM Event Streams Schema Registry Scripts

This directory contains utility scripts for managing schemas in the [IBM Event Streams](https://cloud.ibm.com/docs/services/EventStreams?topic=eventstreams-getting_started) Schema Registry.

## Scripts

### `scripts/import_schemas.sh` — Batch schema import

Imports all schemas from a local export directory into the Schema Registry, preserving the original schema IDs using subject-level `IMPORT` mode.

This is useful when migrating schemas from IBM Event Streams schema registry to Confluent schema registry.

#### Prerequisites

- [`curl`](https://curl.se/)
- [`jq`](https://stedolan.github.io/jq/)

#### Expected export directory layout

The script expects schemas to be arranged in the following layout, as produced by a compatible export process:

```
schema-export/
  <subject-name>/
    v1.json
    v2.json
    ...
```

Each JSON file must contain the fields exported by the Schema Registry API, at minimum:

```json
{
  "subject": "my-topic-value",
  "version": 1,
  "id": 100001,
  "schema": "{\"type\":\"record\", ...}",
  "schemaType": "AVRO"
}
```

#### Usage

Set the `SR_URL` environment variable to your Schema Registry endpoint and run the script:

```bash
SR_URL=https://<your-schema-registry-url> ./scripts/import_schemas.sh
```

You can also override the export directory (default: `./schema-export`):

```bash
SR_URL=https://<your-schema-registry-url> \
  OUT_DIR=/path/to/schema-export \
  ./scripts/import_schemas.sh
```

#### What the script does

For each subject found in the export directory, the script:

1. Switches the subject into `IMPORT` mode — this allows schemas to be registered with their original IDs.
2. Posts each versioned schema file in order.
3. Restores the subject to `READWRITE` mode.

#### Authentication

If your Schema Registry requires authentication, pass credentials via curl's `-u` flag or an `Authorization` header. You can extend the script by adding a `BASIC_AUTH` variable:

```bash
SR_URL=https://<your-schema-registry-url> \
  BASIC_AUTH="token:<api-key>" \
  ./scripts/import_schemas.sh
```

And add `-u "$BASIC_AUTH"` to each `curl` call inside the script.
