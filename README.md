# badlydrawnwizards.com

A blog built with [Verso](https://github.com/leanprover/verso)'s blog genre.

- Preview: `lake build && lake exe generate-blog`, then open `_site/`.
- The site as a Nix derivation: `nix build` (output in `result/`).

## Publishing

millionants serves the site from its `website` flake input. Push here, then in
millionants' repo run `nix flake update website` and deploy.

## Dependencies

`nix build` has no network: every Lake dependency comes from
`lake-manifest.json`, fetched at its pinned rev. After `lake update` or a
version bump, check `nix build` still works.

Lean and Verso versions move together: `lean-toolchain` and verso's `rev` in
`lakefile.toml` should name the same release, and that release needs a manifest
in [lean4-nix](https://github.com/lenianiva/lean4-nix/tree/main/manifests).
