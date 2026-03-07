# Entry point dispatcher
if [ $# -eq 0 ]; then
    echo "Usage: $0 step1 step2 step3:option ..."
    exit 1
fi

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Pre-flight checks
check_root
check_os

for arg in "$@"; do
    case $arg in
        install_php:*)
            PHP_VERSION=${arg#*:}
            install_php
            ;;
        *)
            if declare -f "$arg" > /dev/null; then
                "$arg"
            else
                log_error "Unknown step: $arg"
            fi
            ;;
    esac
done

log_success "All selected steps completed!"
