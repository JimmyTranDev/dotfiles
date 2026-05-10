#!/bin/bash

[[ -n "${_COMMON_DETECT_LOADED:-}" ]] && return 0
_COMMON_DETECT_LOADED=1

detect_node_package_manager() {
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

detect_package_manager() {
	local dir="${1:-.}"

	if [[ -f "$dir/pnpm-lock.yaml" ]]; then
		echo "pnpm"
	elif [[ -f "$dir/yarn.lock" ]]; then
		echo "yarn"
	elif [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
		echo "bun"
	elif [[ -f "$dir/package-lock.json" ]]; then
		echo "npm"
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
	local dir="${1:-.}"

	if [[ -f "$dir/pnpm-lock.yaml" ]]; then
		echo "pnpm"
	elif [[ -f "$dir/yarn.lock" ]]; then
		echo "yarn"
	elif [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
		echo "bun"
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
