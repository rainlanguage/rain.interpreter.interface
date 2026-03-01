# Pass 0: Process Review

Audit date: 2026-03-01
Documents reviewed: CLAUDE.md, README.md, foundry.toml, flake.nix, slither.config.json, .github/workflows/rainix.yaml

## Evidence of Thorough Reading

### CLAUDE.md (73 lines)
- Sections: Project Overview, Build & Development, Architecture (Core Interfaces, Libraries, Key Types, Security Model), Tests, Dependencies, Branch Naming
- Commands listed: nix develop, rainix-sol-prelude, rainix-sol-test, rainix-sol-static, rainix-sol-legal
- Interfaces listed: IInterpreterV4, IInterpreterStoreV3, IInterpreterCallerV4, IParserV2, ISubParserV4, IInterpreterExternV4, IParserPragmaV1
- Libraries listed: LibBytecode, LibContext, LibEvaluable, LibNamespace, LibParseMeta, LibGenParseMeta

### README.md (50 lines)
- Sections: High level, Dev stuff (Local environment & CI), Legal stuff, Contributions

### foundry.toml (28 lines)
- Settings: solc 0.8.25, optimizer true, optimizer_runs 1000000, evm_version cancun, bytecode_hash none, cbor_metadata false, fuzz runs 2048, one remapping

### flake.nix (17 lines)
- Inputs: flake-utils, rainix
- Outputs: packages and devShells from rainix

### slither.config.json (4 lines)
- Excluded detectors: assembly-usage, solc-version, unused-imports, pragma
- Filter paths: forge-std, openzeppelin

### rainix.yaml (43 lines)
- Jobs: rainix-sol-test, rainix-sol-static, rainix-sol-legal
- Steps: checkout with submodules, nix install, cache, prelude, task

## Findings

### A00-1 [LOW] CLAUDE.md says "Requires NixOS" but NixOS is the Linux distribution — what's required is the Nix package manager

CLAUDE.md line 13: "Requires NixOS." The README.md correctly says "Uses nixos" and directs to nix installation. The actual requirement is the Nix package manager (`nix develop`), which runs on macOS and any Linux distro, not just NixOS. A future session on macOS could be confused about whether the tooling works on their platform.

### A00-2 [LOW] CLAUDE.md does not mention `revert("...")` prohibition or other Solidity-specific coding conventions

The project's security model section in CLAUDE.md mentions stateless eval and namespace isolation but does not document Solidity coding conventions that a future session should follow — most importantly, whether string reverts or custom errors are expected. This information exists in the codebase (all errors use custom errors) but is not captured in process docs.

### A00-3 [INFO] README.md says "Install `nix develop`" which is misleading

README.md line 14: "Install `nix develop` - https://nixos.org/download.html" — `nix develop` is a command, not something you install. The instruction should say to install Nix and then run `nix develop`. This is a README issue, not CLAUDE.md, but it's the canonical human-facing setup doc.

### A00-4 [INFO] CLAUDE.md mentions deprecated interfaces but doesn't state policy on modifying them

Line 39: "Deprecated v1/v2 interfaces live in `src/interface/deprecated/`." A future session doesn't know whether these should be left untouched, whether they can be deleted, or whether they might still need updates. Recent git history shows `IParserPragmaV1` was undeprecated (commit 8bb60bc), suggesting the deprecation status is not always final.

### A00-5 [INFO] No instruction on Solidity version policy for new vs. existing files

foundry.toml sets solc 0.8.25, but some interface files use `pragma solidity ^0.8.18` while libraries use `>=0.8.25`. CLAUDE.md doesn't explain when to use which pragma. A future session adding a new file wouldn't know which pragma to use.
