#!/usr/bin/env bash
set -euo pipefail

SCANNER_DIR="${1:-/home/dsoles/Java/spring-analyzer}"
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Building SpringAnalyzer in $SCANNER_DIR..."
(cd "$SCANNER_DIR" && ./mvnw -q clean package)

JAR="$(find "$SCANNER_DIR/target" -maxdepth 1 -type f -name 'spring-analyzer-*.jar' -print -quit)"
if [ -z "$JAR" ]; then
  echo "No JAR found in $SCANNER_DIR/target" >&2
  exit 1
fi

mkdir -p "$PLUGIN_DIR/bin"
cp "$JAR" "$PLUGIN_DIR/bin/spring-analyzer.jar"
echo "JAR copied to $PLUGIN_DIR/bin/spring-analyzer.jar"
