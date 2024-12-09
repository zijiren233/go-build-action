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
          targets: linux/amd64,linux/arm64:nocgo,windows/amd64:cgo
          # targets: linux/*
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
          # show-all-targets: *
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
curl -sL https://raw.githubusercontent.com/zijiren233/go-build-action/refs/tags/v1/build.sh | bash -s -- --show-all-targets
```
