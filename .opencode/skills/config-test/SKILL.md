---
name: config-test
description: Use ONLY when testing configuration changes. Manual testing of config changes is required.
---

# Config Change Validation

Be aware that testing configuration changes is not automatable at the moment.

When you have modified any part of the configuration and are ready to validate the changes, please run the following command in the terminal:

```bash
./rebuild.sh test
```