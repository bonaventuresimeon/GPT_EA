# GPT_EA Certified Release Rollback Package

Every production promotion after the first certified release should retain a rollback package for the **previous certified candidate**. A rollback must restore a known evidence-bound EX5/SET/configuration, not merely copy an old executable from an operator folder.

Schema: `rollback_package_manifest_v1`.

## Package contents

At minimum archive:

- previous release's `release_evidence.json`;
- previous final GO review when available;
- previous certified EX5;
- previous SET/preset when one was part of the release;
- every existing evidence file referenced through an `*_path` field in the release evidence;
- a human migration/rollback note explaining compatible state, Global Variables/checkpoints, broker profile and any data-format changes;
- machine manifest with SHA-256 for every archived file.

The builder deliberately does not create a fake PASS. It only packages files that actually exist and records missing referenced artifacts as a hard error.

## Build

Prepare a migration note, for example:

`artifacts/rollback-migration-notes.md`

Then run:

```text
python tools/build_release_rollback_package.py \
  --release-evidence path/to/previous/release_evidence.json \
  --migration-note artifacts/rollback-migration-notes.md \
  --final-review path/to/previous/final_release_review.json \
  --output artifacts/GPT_EA_previous_certified_rollback.zip
```

Validate independently:

```text
python tools/validate_release_rollback_package.py artifacts/GPT_EA_previous_certified_rollback.zip
```

Archive the emitted validation output and ZIP SHA-256.

## Rollback rule

A rollback may be used only when:

- the package validator passes;
- the target broker/account/symbol contract remains compatible or the deployment matrix is revalidated;
- the stored SET/configuration is restored with the EX5;
- recovery/checkpoint migration notes are followed;
- any newer open position is safely handled before loading the older release.

Do not hot-swap executables around an unmanaged open position merely to recover from a strategy loss. The rollback mechanism is for software/release failures, not performance chasing.
