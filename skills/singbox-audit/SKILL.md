---
description: Use this skill when auditing, reviewing, or checking any sing-box configuration
  file for security issues, routing rules, DNS settings, log configs, protocol correctness,
  or general best practices. Also trigger on "config review", "security check", "protocol
  audit", "routing optimization", "DNS config check", or any request to review a sing-box
  .json config.
name: singbox-audit
---

# Sing-box Configuration Audit

Comprehensive audit of sing-box JSON configuration files. Checks every major area: protocol security, routing rules, DNS settings, log config, and overall correctness.

## Prerequisites

- A sing-box configuration file (JSON format) at a known path, OR base64-encoded config content.
- Optionally, reference to the official sing-box documentation at https://sing-box.sagernet.org for protocol-specific guidance.

## Audit Checklist

For each audit, cover ALL of the following areas:

### 1. Protocol Security

Check every outbounds section (vmess, vless, trojan, shadowsocks, etc.):

- **VMess:** `security` field should be `"auto"` or stronger (e.g., `"aes-128-gcm"`, `"chacha8-poly1305"`). Avoid `"none"` unless explicitly required by compatibility. ⚠️ Do NOT automatically change `"none"` to something else — verify with the user first. Some clients require `security: "none"` for specific proxy servers.
- **VLESS:** Check `flow` field. If `xtls-rprx-vision` flow is set without `multiplex`, consider enabling multiplex for performance.
- **Trojan:** Verify the password is not a common/default value.
- **Shadowsocks:** Check method strength. Prefer `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `aes-128-gcm`, or `chacha8-poly1305`. Avoid weak methods like `plain` or `text`.
- **TLS/Transport:** All public-facing protocols should use TLS (`tls.enabled: true`). Check `serverName`, ALPN settings, and CA paths if using custom certificates.
- **Header:** If `type` is `http` in transport config, verify it matches the actual usage.

### 2. DNS Settings

- Ensure DNS is configured with a valid server list.
- Check `final` policy (recommend `"direct"` or `"dns-default"`).
- Verify `clientSubnet` is set if needed for geo-DNS resolution.
- Look for domain strategies (`"asIs"`, `"iPv4"`, `"iPv6"`, `"preferI iPv4"`).
- Check if `fakeip` is enabled and properly configured for better routing.

### 3. Routing Rules

- Verify `rules` array covers essential categories:
  - Direct domains (CN domestic)
  - Proxy domains (foreign services)
  - Block rules (ads, malware, phishing)
  - IP-based rules (LAN, private networks)
- Check that `domain` and `domain_suffix` rules don't conflict.
- Ensure `ruleSet` references exist and are loadable.
- Look for missing `port` rules for common service ports.

### 4. Log Configuration

- Ensure logging is enabled with appropriate level (`"info"`, `"warn"`, or `"error"`).
- Check timestamp, output path, and file rotation settings.
- Verify `access_log` and `error_log` paths are writable.

### 5. Inbound Configuration

- Ensure `tag` is unique for each inbound.
- Check listener address and port configurations.
- Verify mixed protocol or TCP/UDP separation.
- Ensure no dangerous open ports exposed.

### 6. General Best Practices

- Check for duplicate tags or IDs.
- Verify JSON syntax correctness.
- Ensure all referenced resources (rule sets, certificate files) exist.
- Look for commented-out or deprecated fields.

## Execution Steps

1. **Locate config file:** Read the sing-box configuration from the specified path or process provided content.
2. **Parse structure:** Identify all top-level sections: `inbounds`, `outbounds`, `route`, `dns`, `log`, `experimental`.
3. **Audit each section:** Go through the checklist above systematically.
4. **Prioritize findings:** Categorize issues as:
   - 🔴 Critical: Security vulnerability, broken functionality
   - 🟡 Warning: Suboptimal configuration, potential improvement
   - 🔵 Info: Best practice suggestion, optional optimization
5. **Present report:** List all findings in order of severity with specific fix recommendations.
6. **Wait for approval:** Before making any changes, present the report and ask which issues to fix. Do NOT modify without explicit confirmation.

## Common Fixes Applied on Request

- Enable TLS where missing
- Strengthen weak encryption methods
- Fix DNS routing to prevent leaks
- Add missing routing rules
- Optimize log levels
- Fix duplicate tags or conflicting rules

## Notes

- When fixing, always show the diff/change before applying.
- Never remove a rule without understanding its purpose.
- If using ruleSets (e.g., from h2r or GitHub), ensure URLs are accessible.
- Always validate config after changes: suggest `sing-box check <config-file>` or `sing-box test -c <config-file>`.
- For VMess specifically: `security: "auto"` is recommended for modern clients. `security: "none"` works but may expose vulnerabilities. Only change if user confirms.

## Output Format

ALWAYS use this exact template for findings:

| # | Severity | Area | Issue | Suggested Fix |
|---|----------|------|-------|---------------|
| 1 | 🔴/🟡/🔵 | [section] | [description] | [action] |

Summary: X critical, Y warnings, Z info items. Total lines to modify: N.

<!-- ⟦ singbox-audit Skill created: comprehensive sing-box configuration audit workflow ⟧ -->