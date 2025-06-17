#!/bin/bash

### shfmt -w -s -ci -sr -kp -fn backup-charts.sh

set -euo pipefail

CHARTS_DIR="charts"
TMP_DIR=$(mktemp -d)

# Function to clean up temp directory
cleanup()
{
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Function to discover charts from GitHub OCI registry
discover_gh_oci_charts()
{
	local org="$1"
	echo "Discovering charts from $org org..." >&2

	local charts
	charts=$(gh api "/orgs/$org/packages?package_type=container" | jq -r '.[].name')
	sleep 3

	if [ -z "$charts" ]; then
		echo "No charts found or API call failed for org: $org" >&2
		return 1
	fi

	echo "$charts"
}

# Function to get versions for a chart from GitHub OCI registry
get_gh_oci_chart_versions()
{
	local org="$1"
	local chart="$2"
	local encoded_chart="${chart//\//%2F}" # URL encode the chart name (replace / with %2F)

	gh api "/orgs/$org/packages/container/$encoded_chart/versions" \
		--jq '.[].metadata.container.tags[]?' 2> /dev/null |
		grep -v '^null$' |
		sort -V
	sleep 3
}

# Function to pull and extract chart from OCI registry
pull_oci_chart()
{
	local registry="$1"
	local chart="$2"
	local version="$3"
	local dest_dir="$4"

	if [ -z "$version" ]; then
		return 0
	fi

	echo "Verifying $chart:$version is a valid Helm chart..."

	if ! helm show chart "oci://$registry/$chart" --version "$version" > /dev/null 2>&1; then
		echo "Skipping $chart:$version - not a valid Helm chart"
		sleep 3
		return 0
	fi
	sleep 3

	echo "Downloading $chart:$version"

	mkdir -p "$dest_dir"

	if ! helm pull "oci://$registry/$chart" --version "$version" --destination "$dest_dir" --untar; then
		echo "Failed to pull $chart:$version"
		return 1
	fi
	sleep 3

	return 0
}

# Function to process a single chart
process_chart()
{
	local org="$1"
	local registry="$2"
	local chart="$3"
	local tmp_charts_dir="$4"

	if [ -z "$chart" ]; then
		return 0
	fi

	echo "Processing chart: $chart from org: $org"

	echo "Getting versions..."
	local versions
	versions=$(get_gh_oci_chart_versions "$org" "$chart")

	if [ -z "$versions" ]; then
		echo "No versions found for $chart"
		return 0
	fi

	echo "Found versions: $(echo "$versions" | tr '\n' ' ')"

	while IFS= read -r version; do
		local version_dir="$tmp_charts_dir/$org/$chart/$version"
		pull_oci_chart "$registry" "$chart" "$version" "$version_dir"
	done <<< "$versions"
}

# Function to sync charts to repository
sync_charts()
{
	local src_dir="$1"
	local dest_dir="$2"
	local dry_run="$3"

	echo "Syncing charts to repository..."
	if [[ $dry_run == "true" ]]; then
		echo "DRY RUN: Would sync with the following changes:"
		rsync -av --delete --dry-run "$src_dir/" "$dest_dir/"
		return 0
	else
		rsync -av --delete "$src_dir/" "$dest_dir/"
		echo "Chart backup completed successfully!"
	fi
}

# Main function
main()
{
	local dry_run=false
	local gh_orgs=""

	while [[ $# -gt 0 ]]; do
		case $1 in
			--dry-run)
				dry_run=true
				shift
				;;
			--gh-orgs)
				gh_orgs="$2"
				shift 2
				;;
			*)
				echo "Unknown option: $1"
				echo "Usage: $0 [--dry-run] --gh-orgs \"org1,org2,org3\""
				exit 1
				;;
		esac
	done

	if [ -z "$gh_orgs" ]; then
		echo "Error: --gh-orgs parameter is required"
		echo "Usage: $0 [--dry-run] --gh-orgs \"org1,org2,org3\""
		exit 1
	fi

	local repo_dir
	repo_dir="$(dirname "$0")/.." # go up one level from scripts/ folder

	echo "Starting chart backup process..."
	echo "Temporary directory: $TMP_DIR"
	echo "Organizations: $gh_orgs"

	mkdir -p "$TMP_DIR/$CHARTS_DIR"

	IFS=',' read -ra ORGS_ARRAY <<< "$gh_orgs" # process each organization
	for org in "${ORGS_ARRAY[@]}"; do
		org=$(echo "$org" | xargs) # trim whitespace
		if [ -z "$org" ]; then
			continue
		fi

		echo "Processing organization: $org"
		local registry="ghcr.io/$org"

		local charts
		charts=$(discover_gh_oci_charts "$org")
		if [ -z "$charts" ]; then
			echo "No charts found for org: $org"
			continue
		fi

		echo "Found charts for $org: $(echo "$charts" | tr '\n' ' ')"

		while IFS= read -r chart; do
			process_chart "$org" "$registry" "$chart" "$TMP_DIR/$CHARTS_DIR"
		done <<< "$charts"
	done

	echo "Chart extraction completed"

	sync_charts "$TMP_DIR/$CHARTS_DIR" "$repo_dir/$CHARTS_DIR" "$dry_run"
}

main "$@"
