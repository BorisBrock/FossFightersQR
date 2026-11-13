#!/usr/bin/env bash
# Runs the tests and prints one line per suite.
#   tests/run.sh          the fast headless tests (the default)
#   tests/run.sh gui      only the windowed tests (test_game, test_onboarding)
#   tests/run.sh all      both
# A suite's full output is printed only when it fails.
cd "$(dirname "$0")/.." || exit 1

FAST=(
	"--headless res://tests/check_project.tscn"
	"--headless -s tests/test_decoder.gd"
	"--headless -s tests/test_cards.gd"
	"--headless -s tests/test_party.gd"
	"--headless -s tests/test_fight.gd"
	"--headless -s tests/test_messages.gd"
	"--headless res://tests/test_settings.tscn"
	"--headless res://tests/test_bosses.tscn"
	"--headless res://tests/test_boss_fight.tscn"
)
# These need a window: run headless, they get no camera frames and fail.
# Without vsync, because a compositor may throttle a window nobody looks at to ~1 fps,
# and then every timing check fails.
GUI=(
	"--disable-vsync res://tests/test_game.tscn"
	"--disable-vsync res://tests/test_onboarding.tscn"
)

case "${1:-fast}" in
	fast) SUITES=("${FAST[@]}") ;;
	gui) SUITES=("${GUI[@]}") ;;
	all) SUITES=("${FAST[@]}" "${GUI[@]}") ;;
	*) echo "usage: $0 [fast|gui|all]" >&2; exit 2 ;;
esac

failed=0
for suite in "${SUITES[@]}"; do
	# shellcheck disable=SC2086
	output=$(timeout 300 godot $suite 2>&1)
	status=$?
	name=$(basename "${suite##* }")
	if [[ $status -eq 0 ]] && ! grep -q "FAIL" <<<"$output"; then
		echo "ok    $name"
	else
		echo "FAIL  $name"
		grep -E "FAIL|SCRIPT ERROR|Parse Error" <<<"$output"
		failed=1
	fi
done
exit $failed
