# DuckDB SQL and catalog browser evidence

Playwright Chromium recordings and screenshots use a synthetic connection fixture. The baseline is `521e00d075cc50bfbab281b74a1ef08ee41e3a51` and the feature run is `27620f9de3069060d4c42bba639ac31ad391ca24`.

| Workflow | Before | After |
| --- | --- | --- |
| Catalog tree and row preview | ![One schema and the current orders table](catalog-tree-before.png) | ![Two DuckDB catalogs with distinct orders preview tabs](catalog-tree-after.png) |
| DuckDB SQL and completion | ![Plain SQL text without attached catalog suggestions](catalog-completion-before.png) | ![DuckDB SQL highlighting and attached table and view suggestions](catalog-completion-after.png) |

[Watch the Chromium workflow](catalog-workflow.mp4).
