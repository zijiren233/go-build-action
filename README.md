# Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Go Build
        uses: zijiren233/go-build-action@main
        with:
          targets: linux/amd64,windows/amd64
          enable-micro: true
```

```yaml
jobs:
  get-targets:
    runs-on: ubuntu-latest
    outputs:
      targets: ${{ steps.get_all_targets.outputs.targets }}
    steps:
      - uses: actions/checkout@v4

      - name: Get All Targets
        uses: zijiren233/go-build-action@main
        with:
          show-all-targets: true
          # show-all-targets: linux/*,windows/*

  build-targets:
    runs-on: ubuntu-latest
    needs: get-targets
    strategy:
      matrix:
        target: ${{ fromJson(needs.get_all_targets.outputs.targets) }}
    steps:
      - uses: actions/checkout@v4

      - name: Build Targets
        uses: zijiren233/go-build-action@main
        with:
          targets: ${{ matrix.target }}
```
