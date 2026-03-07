#!/bin/bash

# Ensure git is initialized
if [ ! -d ".git" ]; then
    echo "This is not a git repository. Please run git init first."
    exit 1
fi

HOOK_FILE=".git/hooks/pre-commit"

echo "Setting up pre-commit hook for Pint..."

cat > "$HOOK_FILE" <<EOF
#!/bin/bash

echo "Running Laravel Pint..."
./vendor/bin/pint --test

if [ \$? -ne 0 ]; then
    echo "Pint failed. Fixing code styling..."
    ./vendor/bin/pint
    echo "Style fixed. Please stage your changes and commit again."
    exit 1
fi
EOF

chmod +x "$HOOK_FILE"

echo "Pre-commit hook installed successfully!"
