# Usage

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: 1.23

      - name: Go Build
        uses: zijiren233/go-build-action@v1
        with:
          targets: linux/amd64,linux/arm64,windows/amd64
          # targets: linux/*
          enable-micro: true
```

```yaml
jobs:
  build-targets:
    name: Build targets
    runs-on: ubuntu-latest
    needs: get-targets
    strategy:
      matrix:
        target: ${{ fromJson(needs.get-targets.outputs.targets) }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: 1.23

      - name: Build targets
        uses: zijiren233/go-build-action@v1
        with:
          targets: ${{ matrix.target }}
```

```bash
curl -sL https://raw.githubusercontent.com/zijiren233/go-build-action/refs/tags/v1/cross.sh | bash -s -- --show-all-targets
```
