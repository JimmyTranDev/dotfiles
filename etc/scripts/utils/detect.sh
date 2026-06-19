#!/bin/bash

[[ -n "${_COMMON_DETECT_LOADED:-}" ]] && return 0
_COMMON_DETECT_LOADED=1

# Maps node lockfiles to a manager name with fixed precedence:
# pnpm > yarn > bun > npm (package-lock.json); empty when none match.
# Callers treat "npm" specially: detect_node_runner maps it to "npx".
_detect_node_lock() {
	local dir="${1:-.}"

	if [[ -f "$dir/pnpm-lock.yaml" ]]; then
		echo "pnpm"
	elif [[ -f "$dir/yarn.lock" ]]; then
		echo "yarn"
	elif [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
		echo "bun"
	elif [[ -f "$dir/package-lock.json" ]]; then
		echo "npm"
	else
		echo ""
	fi
}

detect_node_package_manager() {
	_detect_node_lock "${1:-.}"
}

detect_project_package_manager() {
	local dir="${1:-.}"
	local node_pm
	node_pm=$(_detect_node_lock "$dir")

	if [[ -n "$node_pm" ]]; then
		echo "$node_pm"
	elif [[ -f "$dir/pom.xml" ]]; then
		echo "mvn"
	elif [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		if [[ -f "$dir/gradlew" ]]; then
			echo "./gradlew"
		else
			echo "gradle"
		fi
	elif [[ -f "$dir/pyproject.toml" ]]; then
		echo "poetry"
	elif [[ -f "$dir/requirements.txt" ]]; then
		echo "pip"
	elif [[ -f "$dir/go.mod" ]]; then
		echo "go"
	elif [[ -f "$dir/Cargo.toml" ]]; then
		echo "cargo"
	else
		echo ""
	fi
}

detect_node_runner() {
	local node_pm
	node_pm=$(_detect_node_lock "${1:-.}")

	# pnpm/yarn/bun pass through; npm (package-lock.json) and none fall back to npx.
	if [[ -n "$node_pm" && "$node_pm" != "npm" ]]; then
		echo "$node_pm"
	else
		echo "npx"
	fi
}

detect_test_runner() {
	local dir="${1:-.}"

	if [[ -f "$dir/pom.xml" ]]; then
		if grep -q "surefire" "$dir/pom.xml" 2>/dev/null || grep -q "junit" "$dir/pom.xml" 2>/dev/null; then
			echo "maven-surefire"
		else
			echo "maven"
		fi
		return
	fi

	if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		echo "gradle"
		return
	fi

	if [[ -f "$dir/package.json" ]]; then
		if grep -q '"vitest"' "$dir/package.json" 2>/dev/null; then
			echo "vitest"
		elif grep -q '"jest"' "$dir/package.json" 2>/dev/null; then
			echo "jest"
		elif grep -q '"mocha"' "$dir/package.json" 2>/dev/null; then
			echo "mocha"
		else
			echo "npm-test"
		fi
		return
	fi

	if [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/pytest.ini" ]] || [[ -f "$dir/setup.cfg" ]]; then
		echo "pytest"
		return
	fi

	if [[ -f "$dir/go.mod" ]]; then
		echo "go-test"
		return
	fi

	if [[ -f "$dir/Cargo.toml" ]]; then
		echo "cargo-test"
		return
	fi

	echo "unknown"
}

detect_linter() {
	local dir="${1:-.}"

	if [[ -f "$dir/biome.json" ]] || [[ -f "$dir/biome.jsonc" ]]; then
		echo "biome"
		return
	fi

	if ls "$dir"/eslint.config.* 2>/dev/null | head -1 &>/dev/null; then
		echo "eslint"
		return
	fi

	if [[ -f "$dir/.eslintrc" ]] || [[ -f "$dir/.eslintrc.js" ]] || [[ -f "$dir/.eslintrc.json" ]] || [[ -f "$dir/.eslintrc.yml" ]]; then
		echo "eslint"
		return
	fi

	if [[ -f "$dir/pyproject.toml" ]] && grep -q "ruff" "$dir/pyproject.toml" 2>/dev/null; then
		echo "ruff"
		return
	fi

	if [[ -f "$dir/.golangci.yml" ]] || [[ -f "$dir/.golangci.yaml" ]]; then
		echo "golangci-lint"
		return
	fi

	if [[ -f "$dir/Cargo.toml" ]]; then
		echo "clippy"
		return
	fi

	if [[ -f "$dir/pom.xml" ]] && grep -q "checkstyle" "$dir/pom.xml" 2>/dev/null; then
		echo "checkstyle-maven"
		return
	fi

	if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		local gradle_file="$dir/build.gradle"
		if [[ -f "$dir/build.gradle.kts" ]]; then
			gradle_file="$dir/build.gradle.kts"
		fi
		if grep -q "checkstyle" "$gradle_file" 2>/dev/null; then
			echo "checkstyle-gradle"
			return
		fi
	fi

	echo "none"
}

detect_formatter() {
	local dir="${1:-.}"

	if [[ -f "$dir/biome.json" ]] || [[ -f "$dir/biome.jsonc" ]]; then
		echo "biome"
		return
	fi

	if [[ -f "$dir/package.json" ]]; then
		if grep -q '"prettier"' "$dir/package.json" 2>/dev/null; then
			echo "prettier"
			return
		fi
	fi

	if [[ -f "$dir/.prettierrc" ]] || [[ -f "$dir/.prettierrc.js" ]] || [[ -f "$dir/.prettierrc.json" ]] || [[ -f "$dir/.prettierrc.yml" ]] || [[ -f "$dir/prettier.config.js" ]] || [[ -f "$dir/prettier.config.mjs" ]]; then
		echo "prettier"
		return
	fi

	if [[ -f "$dir/pyproject.toml" ]] && grep -q "black" "$dir/pyproject.toml" 2>/dev/null; then
		echo "black"
		return
	fi

	if [[ -f "$dir/go.mod" ]]; then
		echo "gofmt"
		return
	fi

	if [[ -f "$dir/Cargo.toml" ]]; then
		echo "rustfmt"
		return
	fi

	echo "none"
}

detect_type_checker() {
	local dir="${1:-.}"

	if [[ -f "$dir/tsconfig.json" ]]; then
		echo "tsc"
		return
	fi

	if [[ -f "$dir/mypy.ini" ]] || [[ -f "$dir/setup.cfg" ]] && grep -q "mypy" "$dir/setup.cfg" 2>/dev/null; then
		echo "mypy"
		return
	fi

	if [[ -f "$dir/pyproject.toml" ]] && grep -q "mypy" "$dir/pyproject.toml" 2>/dev/null; then
		echo "mypy"
		return
	fi

	if [[ -f "$dir/Cargo.toml" ]]; then
		echo "cargo-check"
		return
	fi

	echo "none"
}

require_command() {
	local cmd="$1"
	local hint="${2:-}"
	if ! command -v "$cmd" &>/dev/null; then
		local msg="Required command '$cmd' not found"
		if [[ -n "$hint" ]]; then
			msg="$msg. Install: $hint"
		fi
		echo "$msg" >&2
		return 1
	fi
}

detect_build_command() {
	local dir="${1:-.}"

	if [[ -f "$dir/package.json" ]]; then
		if grep -q '"build"' "$dir/package.json" 2>/dev/null; then
			local pm
			pm=$(detect_node_runner "$dir")
			echo "$pm:build"
			return
		fi
	fi

	if [[ -f "$dir/pom.xml" ]]; then
		echo "mvn:package"
		return
	fi

	if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		if [[ -f "$dir/gradlew" ]]; then
			echo "./gradlew:build"
		else
			echo "gradle:build"
		fi
		return
	fi

	if [[ -f "$dir/Cargo.toml" ]]; then
		echo "cargo:build"
		return
	fi

	if [[ -f "$dir/go.mod" ]]; then
		echo "go:build"
		return
	fi

	echo "none"
}
