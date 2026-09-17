# GPT_EA Anti-Piracy and License-Enforcement Policy

This policy combines contractual anti-theft rules with recommended technical controls.

## 1. Protected materials

Protected GPT_EA materials may include:
- EX5 binaries;
- source files;
- proprietary prompts;
- strategy logic;
- documentation;
- release manifests;
- presets;
- license tokens;
- branding;
- customer-only updates.

## 2. Unauthorized activity

Prohibited activity includes unauthorized copying, resale, redistribution, cracking, bypassing license checks, tampering with release gates, sharing license credentials, impersonating the Licensor, removing ownership notices, and using stolen source/binaries.

Reverse-engineering restrictions apply only to the extent permitted by mandatory law.

## 3. Recommended distribution model

For ordinary customers:
- distribute signed/hashed EX5, not source;
- distribute a clean preset with blank API-key fields;
- issue a unique customer license reference;
- bind commercial entitlement only to disclosed minimum identifiers;
- never embed private signing secrets in the customer EA;
- keep signing/verification authority outside distributable source where possible.

## 4. Recommended signed-license architecture

A stronger production architecture is:

    Customer purchase
    -> license service issues signed entitlement
    -> entitlement contains license ID, product/release scope, expiry/renewal state, permitted account/server count
    -> GPT_EA verifies signature/public key
    -> periodic validation/revocation check when online
    -> short offline grace period
    -> fail closed for new entries after invalid/revoked entitlement
    -> continue safe management of already-open positions

The EA should never abandon protection of an existing trade merely because a license check fails.

## 5. Privacy-minimized binding

Prefer the minimum data needed, for example:
- hashed/derived account identifier;
- broker server;
- license ID;
- product/release version.

Do not collect MT5 passwords, OpenAI API keys or unnecessary financial data for licensing.

## 6. Tamper evidence

Recommended controls:
- publish/ship EX5 SHA-256;
- signed release manifest;
- release ID inside EA;
- integrity-aware support process;
- reject unknown/tampered builds from official support;
- unique license/reference correlation;
- audit revocations without logging secrets.

## 7. License sharing

A customer may not share a single-user/single-account license beyond its purchased scope.

Multi-account, prop-firm, team or commercial signal use should require an appropriate license tier.

## 8. Enforcement

For material piracy/circumvention, the Licensor may, subject to applicable law:
- suspend/revoke the license;
- deny updates/support for unauthorized builds;
- preserve evidence;
- issue takedown notices;
- pursue contractual, copyright or other lawful remedies.

## 9. No unsafe kill switch

Anti-piracy enforcement must not intentionally:
- remove a protective stop from an open trade;
- open revenge/penalty trades;
- change risk to punish a user;
- damage the customer's terminal/files;
- collect passwords/secrets;
- interfere with unrelated software.

License failure should block **new entries** while allowing safe management/closure of existing GPT_EA positions.

## 10. Source-license customers

If source code is sold, use a separate source-code license with stronger confidentiality, derivative-work, redistribution and audit provisions. A binary customer license is not sufficient for source distribution.
