{
  description = "badlydrawnwizards.com, a Verso blog";

  inputs = {
    lean4-nix.url = "github:lenianiva/lean4-nix";
    nixpkgs.follows = "lean4-nix/nixpkgs";
  };

  outputs = { nixpkgs, lean4-nix, ... }:
    let
      systems = [ "aarch64-linux" "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        overlays = [ (lean4-nix.readToolchainFile ./lean-toolchain) ];
      }));
    in
    {
      packages = forAll (pkgs:
        let
          lake2nix = pkgs.callPackage lean4-nix.lake { };
          manifest = pkgs.lib.importJSON ./lake-manifest.json;
          pinned = name: pkgs.lib.findFirst (p: p.name == name) null manifest.packages;

          # Builds these libraries' shared/static facets, which a read-only
          # dependency needs; lake2nix only guesses the capitalised package name.
          buildLibs = libs: {
            buildPhase = ''
              runHook preBuild
              lake build ${pkgs.lib.concatMapStringsSep " " (l: "${l}:shared ${l}:static") libs}
              runHook postBuild
            '';
          };

          # subverso has no dependencies and so no lake-manifest.json, which
          # lake2nix reads at evaluation time. Build it directly, laid out as
          # lake2nix lays out a dependency (source plus .lake).
          subverso = pkgs.stdenv.mkDerivation ({
            name = "subverso";
            src = builtins.fetchGit { inherit (pinned "subverso") url rev; shallow = true; };
            nativeBuildInputs = [ pkgs.rsync pkgs.lean.lean-all ];
            installPhase = ''
              mkdir -p $out
              rsync -a --exclude=".lake" --filter=":- .gitignore" ./ "$out/"
              cp -rP .lake $out
            '';
          } // buildLibs [ "SubVerso" ]);

          # Dependencies come from lake-manifest.json, each fetched at its
          # pinned rev; the build itself has no network.
          generator = lake2nix.mkPackage {
            name = "generate-blog";
            src = ./.;
            depOverrideDeriv = { inherit subverso; };
            depOverride.verso = buildLibs [ "VersoUtil" "Verso" "MultiVerso" "VersoSearch" "VersoBlog" ];
          };
        in
        {
          inherit generator;
          # The static site. The generator expects to run in the project
          # (it looks for lean-toolchain), which lake2nix installs with it.
          default = pkgs.runCommand "badlydrawnwizards.com" { } ''
            cd ${generator}
            ${generator}/bin/generate-blog --output $out
          '';
        });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell { packages = [ pkgs.lean.lean-all ]; };
      });
    };
}
