.PHONY: build-js run-js proof test-js test-bun-import

BEND_LOADER = .build/bend-v2.0.27/bend2/main.ts

$(BEND_LOADER):
	mkdir -p .build
	git clone --depth 1 --branch v2.0.27 https://github.com/bendlang/bend.git .build/bend-v2.0.27

test-bun-import: $(BEND_LOADER)
	@test "$$(git -C .build/bend-v2.0.27 rev-parse HEAD)" = 63bee70b55a71024d6bdcb49a745111bc54b114e
	bun --preload ./$(BEND_LOADER) docs/2026-09-25/bun-import-smoke.js

build-js:
	mkdir -p .build
	bend main.bend -o .build/main.js

run-js: build-js
	bun .build/main.js

proof:
	bend PROOF.bend

# 検証専用DBを毎回新規作成する。結果は調査用に残す。
test-js: proof build-js
	@set -eu; \
	test_dir=$$(mktemp -d .build/test-js.XXXXXX); \
	python3 docs/2026-09-25/test_sqlite.py --db "$$test_dir/app.sqlite" bun .build/main.js
