# Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Go Build
        uses: zijiren233/go-build-action@v1
        with:
          targets: linux/amd64,windows/amd64
          enable-micro: true
```

```yaml
jobs:
  get-targets:
    name: Get targets
    runs-on: ubuntu-latest
    outputs:
      targets: ${{ steps.get-targets.outputs.targets }}
    steps:
      - uses: actions/checkout@v4

      - name: Get targets
        id: get-targets
        uses: zijiren233/go-build-action@v1
        with:
          show-all-targets: true
          # show-all-targets: linux/*,windows/*

  build-targets:
    name: Build targets
    runs-on: ubuntu-latest
    needs: get-targets
    strategy:
      matrix:
        target: ${{ fromJson(needs.get-targets.outputs.targets) }}
    steps:
      - uses: actions/checkout@v4

      - name: Build targets
        uses: zijiren233/go-build-action@v1
        with:
          targets: ${{ matrix.target }}
```

```bash
curl -sL https://github.com/zijiren233/go-build-action/releases/download/v1/build.sh | bash -s -- --show-all-targets
```
