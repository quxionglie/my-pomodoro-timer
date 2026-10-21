#!/bin/bash
# Called by Makefile. Credentials remain in the macOS Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

profile="${NOTARY_PROFILE:-pomodoro-notary}"
timeout="${NOTARY_TIMEOUT:-30m}"
state_dir="${NOTARY_DIR:-build}"
id_file="$state_dir/notarization-submission-id.txt"
mkdir -p "$state_dir"

submission_id() {
    if [[ -n "${1:-}" ]]; then
        printf '%s\n' "$1"
    elif [[ -s "$id_file" ]]; then
        cat "$id_file"
    else
        echo 'No saved submission. Specify ID=YOUR_SUBMISSION_ID.' >&2
        return 1
    fi
}

run_and_check() {
    local output command_status=0 received_id
    output="$state_dir/notarization-$(date +%Y%m%d-%H%M%S)-$$.log"
    xcrun notarytool "$@" --keychain-profile "$profile" 2>&1 | tee "$output" || command_status=$?
    received_id="$(awk '/^[[:space:]]*id: / { print $2; exit }' "$output" | tr -d '\r')"
    if [[ -n "$received_id" ]]; then
        printf '%s\n' "$received_id" > "$id_file"
    fi
    printf 'Notary log: %s\n' "$output"
    if (( command_status != 0 )); then
        echo 'Notarization did not complete. Inspect the log before retrying; an ID alone does not confirm upload completion.' >&2
        return "$command_status"
    fi
    # notarytool can return a successful exit status for a rejected submission.
    if ! awk '/^[[:space:]]*status: Accepted[[:space:]]*$/ { accepted=1 } END { exit !accepted }' "$output"; then
        echo 'No Accepted result. Stopping before stapling or packaging.' >&2
        return 1
    fi
}

case "${1:-}" in
    submit)
        [[ -f "${2:-}" ]] || { echo 'Upload ZIP does not exist. Run make notarize first.' >&2; exit 1; }
        acceleration=()
        case "${NOTARY_ACCELERATION:-0}" in
            0) acceleration=(--no-s3-acceleration) ;;
            1) acceleration=(--s3-acceleration) ;;
            *) echo 'NOTARY_ACCELERATION must be 0 or 1.' >&2; exit 1 ;;
        esac
        run_and_check submit "$2" "${acceleration[@]}" --wait --timeout "$timeout"
        ;;
    wait)
        selected_id="$(submission_id "${2:-}")"
        run_and_check wait "$selected_id" --timeout "$timeout"
        ;;
    status)
        selected_id="$(submission_id "${2:-}")"
        xcrun notarytool info "$selected_id" --keychain-profile "$profile"
        ;;
    log)
        selected_id="$(submission_id "${2:-}")"
        xcrun notarytool log "$selected_id" --keychain-profile "$profile" "$state_dir/notarization-$selected_id.json"
        ;;
    *) echo 'Usage: notarize.sh submit ZIP | wait [ID] | status [ID] | log [ID]' >&2; exit 2 ;;
esac
