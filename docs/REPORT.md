# Diagnostic reports

Create a sanitized report:

```bash
sudo vpn report
```

Reports are stored in:

```text
/opt/vpn-manager/reports/
```

The command creates:

- `vpn-report-YYYY-MM-DD-HHMMSS.tar.gz`
- matching `.sha256` checksum

The report includes system state, service status, ports, routes, logs,
Xray version and configuration test result.

The report intentionally does **not** include the contents of Xray `config.json`,
Reality private keys, client UUIDs, panel passwords or Telegram tokens.

Always review the archive before sharing it.
