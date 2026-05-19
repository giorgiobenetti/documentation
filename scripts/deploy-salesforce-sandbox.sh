#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORG="${1:-}"

if [[ -z "${ORG}" ]]; then
  echo "Uso: $0 <alias-org-sf>"
  echo ""
  echo "Esempio (dopo: sf org login web --instance-url https://test.salesforce.com --alias MIO_SANDBOX):"
  echo "  $0 MIO_SANDBOX"
  exit 1
fi

cd "${ROOT}"

if ! command -v sf >/dev/null 2>&1; then
  echo "Comando 'sf' non trovato. Installa la CLI: npm install -g @salesforce/cli"
  exit 1
fi

echo "Deploy verso org: ${ORG}"
sf project deploy start \
  --source-dir force-app \
  --target-org "${ORG}" \
  --test-level RunSpecifiedTests \
  --tests CaseEmailComposerControllerTest

echo ""
echo "Deploy completato. Assegna il permission set Case Smart Email Reply e aggiorna i record Reply Email Mapping in Setup."
