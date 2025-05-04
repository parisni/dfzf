.DEFAULT_GOAL := help
.PHONY: help release

help:   ## List commands
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

release-patch: ## Release patch
	$(MAKE) do-release-patch

release-minor: ## Release minor
	$(MAKE) do-release-minor

release-major: ## Release major
	$(MAKE) do-release-major

changelog: ## Generates the changelog
	git-chglog --output CHANGELOG.md
	git add CHANGELOG.md
	git commit --amend --no-edit

do-release-%:
	@echo "Creating $* release..."
	git checkout main
	git fetch --force --tags
	bump2version --allow-dirty $*
	$(MAKE) changelog
	git push origin main --tags

