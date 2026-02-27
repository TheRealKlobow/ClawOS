# Build Flow

1. Validate environment (`scripts/lint.sh` + template checks).
2. Prepare base image (`image/scripts/prepare-base-image.sh`).
3. Inject overlay (`image/scripts/inject-overlay.sh`).
4. Enable required services (`image/scripts/enable-services.sh`).
5. Validate image (`image/scripts/validate-image.sh`).
6. Publish artifacts (`scripts/release-image.sh`).

All steps are scriptable and non-interactive.
